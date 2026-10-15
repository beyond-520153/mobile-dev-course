-- =============================================================================
-- KFC 风格点餐系统 —— 数据库初始化脚本
-- 数据库：PostgreSQL 17      库名：kfc      账号：postgres / postgres      端口：5432
-- =============================================================================
--
-- 【这份脚本是设计草案，字段需要你确认后再定稿】
--
-- 当前 backend 的 JPA 配置是 ddl-auto: update，而实体只保留了主键 id。
-- 建表方式请二选一，不要两套同时用：
--   方案 A（推荐）：用本脚本建表 → 我把实体字段补齐 → ddl-auto 改成 validate
--   方案 B        ：不跑本脚本，完全让 Hibernate 按实体自动建表（适合快速试错）
--
-- 执行方式：
--   psql -h 127.0.0.1 -p 5432 -U postgres -d kfc -f V1__init_schema.sql
-- 或双击 D:\devtools\scripts\start-all.bat 起库后，用 DBeaver / pgAdmin 导入。
--
-- 约定：
--   * 主键统一 BIGSERIAL（自增 bigint），对应 Java 的 Long
--   * 金额统一 NUMERIC(10,2)，禁止用 float/double
--   * 时间统一 TIMESTAMPTZ（带时区），对应 Java 的 OffsetDateTime / Instant
--   * updated_at 由应用层维护（本脚本不建触发器，便于讲解与调试）
--   * 表名前缀 t_，避免与 SQL 关键字冲突（如 order 是保留字，故用 t_order）
-- =============================================================================

-- 需要重建时再手工执行下面这段（默认注释掉，避免误删数据）
-- DROP TABLE IF EXISTS t_order_item CASCADE;
-- DROP TABLE IF EXISTS t_order      CASCADE;
-- DROP TABLE IF EXISTS t_cart_item  CASCADE;
-- DROP TABLE IF EXISTS t_address    CASCADE;
-- DROP TABLE IF EXISTS t_product    CASCADE;
-- DROP TABLE IF EXISTS t_category   CASCADE;
-- DROP TABLE IF EXISTS t_user       CASCADE;


-- =============================================================================
-- 1. 用户
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_user (
    id          BIGSERIAL    PRIMARY KEY,
    username    VARCHAR(50)  NOT NULL,                                    -- 登录名
    password    VARCHAR(100) NOT NULL,                                    -- 密码（存 BCrypt 哈希，禁止明文）
    phone       VARCHAR(20),                                              -- 手机号
    nickname    VARCHAR(50),                                              -- 昵称
    avatar      VARCHAR(255),                                             -- 头像地址
    role        VARCHAR(20)  NOT NULL DEFAULT 'CUSTOMER',                 -- CUSTOMER / STAFF / ADMIN
    status      SMALLINT     NOT NULL DEFAULT 1,                          -- 1 正常 0 禁用
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_user IS '用户表（顾客 / 店员 / 管理员）';

CREATE UNIQUE INDEX IF NOT EXISTS uk_user_username ON t_user (username);
CREATE UNIQUE INDEX IF NOT EXISTS uk_user_phone    ON t_user (phone) WHERE phone IS NOT NULL;


-- =============================================================================
-- 2. 餐品分类
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_category (
    id          BIGSERIAL    PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL,                                    -- 分类名，如「主食」「小食」「饮品」
    sort_order  INTEGER      NOT NULL DEFAULT 0,                          -- 排序，越小越靠前
    icon        VARCHAR(255),                                             -- 分类图标地址
    status      SMALLINT     NOT NULL DEFAULT 1,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_category IS '餐品分类表';

CREATE UNIQUE INDEX IF NOT EXISTS uk_category_name ON t_category (name);
CREATE INDEX IF NOT EXISTS idx_category_sort ON t_category (sort_order, id);


-- =============================================================================
-- 3. 餐品
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_product (
    id           BIGSERIAL     PRIMARY KEY,
    category_id  BIGINT        NOT NULL REFERENCES t_category (id),
    name         VARCHAR(100)  NOT NULL,
    description  VARCHAR(500),                                            -- 描述／口味说明
    price        NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    image        VARCHAR(255),                                            -- 餐品图地址
    stock        INTEGER       NOT NULL DEFAULT 0 CHECK (stock >= 0),     -- 库存，0 表示售罄
    sort_order   INTEGER       NOT NULL DEFAULT 0,
    status       SMALLINT      NOT NULL DEFAULT 1,                        -- 1 上架 0 下架
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_product IS '餐品表';

CREATE INDEX IF NOT EXISTS idx_product_category ON t_product (category_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_product_status   ON t_product (status);


-- =============================================================================
-- 4. 收货地址
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_address (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES t_user (id) ON DELETE CASCADE,
    receiver    VARCHAR(50)  NOT NULL,                                    -- 收货人
    phone       VARCHAR(20)  NOT NULL,
    province    VARCHAR(50),
    city        VARCHAR(50),
    district    VARCHAR(50),
    detail      VARCHAR(255) NOT NULL,                                    -- 详细地址
    is_default  BOOLEAN      NOT NULL DEFAULT FALSE,                      -- 是否默认地址
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_address IS '收货地址表';

CREATE INDEX IF NOT EXISTS idx_address_user ON t_address (user_id);
-- 同一用户最多一个默认地址
CREATE UNIQUE INDEX IF NOT EXISTS uk_address_default
    ON t_address (user_id) WHERE is_default = TRUE;


-- =============================================================================
-- 5. 购物车项
-- 说明：购物车同时会缓存一份到 Redis（key: kfc:cart:{userId}），
--       本表作为持久化兜底，保证 Redis 重启后数据不丢。
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_cart_item (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES t_user (id) ON DELETE CASCADE,
    product_id  BIGINT       NOT NULL REFERENCES t_product (id) ON DELETE CASCADE,
    quantity    INTEGER      NOT NULL CHECK (quantity > 0),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_cart_item IS '购物车项表';

CREATE UNIQUE INDEX IF NOT EXISTS uk_cart_user_product ON t_cart_item (user_id, product_id);


-- =============================================================================
-- 6. 订单主表
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_order (
    id           BIGSERIAL     PRIMARY KEY,
    order_no     VARCHAR(32)   NOT NULL,                                  -- 业务订单号，如 20261015xxxx
    user_id      BIGINT        NOT NULL REFERENCES t_user (id),
    address_id   BIGINT        REFERENCES t_address (id),                 -- 堂食/自取时可为空
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),        -- 商品总额
    pay_amount   NUMERIC(10,2) NOT NULL CHECK (pay_amount >= 0),          -- 实付（扣优惠后）
    status       VARCHAR(20)   NOT NULL DEFAULT 'PENDING_PAYMENT',        -- 见 OrderStatus 枚举
    remark       VARCHAR(255),                                            -- 备注（如「不要生菜」）
    pay_time     TIMESTAMPTZ,                                             -- 支付时间
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_order IS '订单主表';

CREATE UNIQUE INDEX IF NOT EXISTS uk_order_no   ON t_order (order_no);
CREATE INDEX IF NOT EXISTS idx_order_user       ON t_order (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_status     ON t_order (status);


-- =============================================================================
-- 7. 订单明细
-- 说明：name / price 是下单时的快照，餐品后续改价改名不影响历史订单。
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_order_item (
    id            BIGSERIAL     PRIMARY KEY,
    order_id      BIGINT        NOT NULL REFERENCES t_order (id) ON DELETE CASCADE,
    product_id    BIGINT        NOT NULL REFERENCES t_product (id),
    product_name  VARCHAR(100)  NOT NULL,                                 -- 下单时餐品名快照
    product_image VARCHAR(255),                                           -- 下单时图片快照
    price         NUMERIC(10,2) NOT NULL CHECK (price >= 0),              -- 下单时单价快照
    quantity      INTEGER       NOT NULL CHECK (quantity > 0),
    subtotal      NUMERIC(10,2) NOT NULL CHECK (subtotal >= 0),           -- price * quantity
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_order_item IS '订单明细表';

CREATE INDEX IF NOT EXISTS idx_order_item_order ON t_order_item (order_id);


-- =============================================================================
-- 8. 初始化数据（可选，方便前端联调时页面不是空的）
--    不需要就整段注释掉。
-- =============================================================================
INSERT INTO t_category (name, sort_order, status) VALUES
    ('主食',  1, 1),
    ('小食',  2, 1),
    ('饮品',  3, 1),
    ('套餐',  4, 1)
ON CONFLICT (name) DO NOTHING;

INSERT INTO t_product (category_id, name, description, price, stock, sort_order, status)
SELECT c.id, v.name, v.descr, v.price, 999, v.so, 1
FROM (VALUES
    ('主食', '香辣鸡腿堡', '经典香辣口味',        21.50, 1),
    ('主食', '新奥尔良烤鸡腿堡', '微甜不辣',      22.50, 2),
    ('小食', '薯条（大）', '现炸酥脆',            12.00, 1),
    ('小食', '上校鸡块（5块）', '配番茄酱',       13.50, 2),
    ('饮品', '百事可乐（中）', '冰',               9.00, 1),
    ('饮品', '美式咖啡', '无糖可选',              15.00, 2),
    ('套餐', '双人分享餐', '汉堡2份+小食2份+饮品2杯', 68.00, 1)
) AS v(cat, name, descr, price, so)
JOIN t_category c ON c.name = v.cat
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. 自检：建完表跑一下，确认 7 张表都在
-- =============================================================================
-- SELECT table_name FROM information_schema.tables
--  WHERE table_schema = 'public' AND table_name LIKE 't_%'
--  ORDER BY table_name;
