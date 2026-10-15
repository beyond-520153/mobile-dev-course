-- =============================================================================
-- KFC 风格点餐系统 —— 数据库初始化脚本
-- 数据库：PostgreSQL 17      库名：kfc      账号：postgres / postgres      端口：5432
-- =============================================================================
--
-- 执行方式：
--   psql -h 127.0.0.1 -p 5432 -U postgres -d kfc -f V1__init_schema.sql
--
-- 本脚本是表结构的唯一事实来源：backend 的 spring.jpa.hibernate.ddl-auto 已设为 none，
-- 不让 Hibernate 自动改表。要改字段请改这里 + 对应的实体，两边必须一致。
--
-- 约定：
--   * 主键统一 BIGSERIAL（自增 bigint），对应 Java 的 Long
--   * 金额统一 NUMERIC(10,2)，对应 Java 的 BigDecimal，禁止用 float/double
--   * 时间统一 TIMESTAMPTZ（带时区），对应 Java 的 OffsetDateTime
--   * 状态位统一 INTEGER + 注释说明，不搞自定义类型，方便用 psql 直接看
--   * created_at / updated_at 由应用层（实体里的 @PrePersist / @PreUpdate）维护，
--     本脚本只给 DEFAULT 作为兜底，不建触发器，便于调试与讲解
--   * 表名前缀 t_，避免与 SQL 关键字冲突（order 是保留字，故用 t_order）
--   * 分类用显式外键列（category_id / user_id / product_id / order_id），
--     不用关联表，实体侧也用 Long 存，查询可控、没有懒加载坑
-- =============================================================================

-- 需要重建时手工执行下面这段（默认注释掉，避免误删数据）
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
    username    VARCHAR(50)  NOT NULL,                       -- 登录名
    password    VARCHAR(100) NOT NULL,                       -- 「盐$SHA-256(盐+明文)」，明文禁止落库
    phone       VARCHAR(20),
    nickname    VARCHAR(50),
    avatar      VARCHAR(255),
    role        VARCHAR(20)  NOT NULL DEFAULT 'CUSTOMER',    -- CUSTOMER / STAFF / ADMIN
    status      INTEGER      NOT NULL DEFAULT 1,             -- 1 正常 0 禁用
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
    name        VARCHAR(50)  NOT NULL,                       -- 分类名，如「汉堡主食」
    sort_order  INTEGER      NOT NULL DEFAULT 0,             -- 排序，越小越靠前
    icon        VARCHAR(255),
    status      INTEGER      NOT NULL DEFAULT 1,
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
    description  VARCHAR(500),
    price        NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    image        VARCHAR(255),                               -- 有图填 URL；联调期放 emoji 占位，前端按图/文两种方式渲染
    stock        INTEGER       NOT NULL DEFAULT 0 CHECK (stock >= 0),
    sort_order   INTEGER       NOT NULL DEFAULT 0,
    status       INTEGER       NOT NULL DEFAULT 1,           -- 1 上架 0 下架
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
    receiver    VARCHAR(50)  NOT NULL,
    phone       VARCHAR(20)  NOT NULL,
    province    VARCHAR(50),
    city        VARCHAR(50),
    district    VARCHAR(50),
    detail      VARCHAR(255) NOT NULL,
    is_default  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_address IS '收货地址表';

CREATE INDEX IF NOT EXISTS idx_address_user ON t_address (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS uk_address_default
    ON t_address (user_id) WHERE is_default = TRUE;          -- 同一用户最多一个默认地址


-- =============================================================================
-- 5. 购物车项
-- 说明：购物车同时会缓存一份 Hash 到 Redis（key: kfc:cart:{userId}），
--       本表是持久化的唯一事实来源，Redis 重启后数据不丢。
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
    order_no     VARCHAR(32)   NOT NULL,
    user_id      BIGINT        NOT NULL REFERENCES t_user (id),
    address_id   BIGINT        REFERENCES t_address (id),    -- 到店自取时为 NULL
    pickup_type  VARCHAR(20)   NOT NULL DEFAULT 'PICKUP',    -- PICKUP 到店自取 / DELIVERY 外送
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    pay_amount   NUMERIC(10,2) NOT NULL CHECK (pay_amount >= 0),
    status       VARCHAR(20)   NOT NULL DEFAULT 'PENDING_PAYMENT',
    remark       VARCHAR(255),
    pickup_code  VARCHAR(10),                                -- 支付后生成，凭码取餐
    pay_time     TIMESTAMPTZ,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_order IS '订单主表';

CREATE UNIQUE INDEX IF NOT EXISTS uk_order_no ON t_order (order_no);
CREATE INDEX IF NOT EXISTS idx_order_user    ON t_order (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_status  ON t_order (status);


-- =============================================================================
-- 7. 订单明细
-- 说明：product_name / product_image / price 是下单那一刻的快照，
--       餐品后续改名改价不影响历史订单。
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_order_item (
    id            BIGSERIAL     PRIMARY KEY,
    order_id      BIGINT        NOT NULL REFERENCES t_order (id) ON DELETE CASCADE,
    product_id    BIGINT        NOT NULL REFERENCES t_product (id),
    product_name  VARCHAR(100)  NOT NULL,
    product_image VARCHAR(255),
    price         NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    quantity      INTEGER       NOT NULL CHECK (quantity > 0),
    subtotal      NUMERIC(10,2) NOT NULL CHECK (subtotal >= 0),
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_order_item IS '订单明细表';

CREATE INDEX IF NOT EXISTS idx_order_item_order ON t_order_item (order_id);


-- =============================================================================
-- 8. 初始化 / 补偿数据（幂等，可重复执行）
--    这些数据是前后端联调用的，上线前替换成真实菜单。
-- =============================================================================

-- 8.1 演示账号：demo / 123456
--     密码按「盐$SHA-256(盐+明文)」存的，和 UserServiceImpl 的算法一致
INSERT INTO t_user (username, password, phone, nickname, role, status) VALUES
    ('demo', 'kfcdemo0salt0001$1a4eb93404c8e27a999f25832b30def1cb22076d39b2e5b5700b355d1904c542',
     '13800000000', 'KFC 会员', 'CUSTOMER', 1)
ON CONFLICT (username) DO NOTHING;

-- 8.2 演示收货地址
INSERT INTO t_address (user_id, receiver, phone, province, city, district, detail, is_default)
SELECT u.id, '张同学', '13800000000', '浙江省', '杭州市', '临安区', '浙江农林大学 东湖校区 学生公寓 3 号楼', TRUE
FROM t_user u
WHERE u.username = 'demo'
  AND NOT EXISTS (SELECT 1 FROM t_address a WHERE a.user_id = u.id);

-- 8.3 分类
INSERT INTO t_category (name, sort_order, status) VALUES
    ('优惠套餐', 1, 1),
    ('汉堡主食', 2, 1),
    ('炸鸡小食', 3, 1),
    ('甜品饮料', 4, 1)
ON CONFLICT (name) DO NOTHING;

-- 8.4 餐品（image 字段联调期放 emoji，前端按字符渲染；换成真图时改成图片 URL 即可）
INSERT INTO t_product (category_id, name, description, price, image, stock, sort_order, status)
SELECT c.id, v.name, v.descr, v.price, v.img, 200, v.so, 1
FROM (VALUES
    ('优惠套餐', '单人超值午餐',   '香辣鸡腿堡 + 薯条(中) + 可乐(中)', 32.00, '🍱', 1),
    ('优惠套餐', '双人分享餐',     '2 个汉堡 + 2 份小食 + 2 杯饮料',   68.00, '🍱', 2),
    ('优惠套餐', '疯狂星期四套餐', '香辣鸡翅 8 块 + 可乐 2 杯',        39.90, '🍗', 3),

    ('汉堡主食', '香辣鸡腿堡',     '经典香辣口味，微辣',               21.50, '🍔', 1),
    ('汉堡主食', '新奥尔良烤鸡腿堡', '微甜不辣，烤制',                 22.50, '🥪', 2),
    ('汉堡主食', '老北京鸡肉卷',   '京味甜面酱 + 黄瓜条',              18.00, '🌯', 3),
    ('汉堡主食', '深海鳕鱼堡',     '鳕鱼排 + 塔塔酱',                  20.00, '🐟', 4),

    ('炸鸡小食', '薯条（大）',     '现炸酥脆，配番茄酱',               12.00, '🍟', 1),
    ('炸鸡小食', '上校鸡块（5块）', '外酥里嫩',                        13.50, '🍗', 2),
    ('炸鸡小食', '香辣鸡翅（2块）', '经典香辣，微辣',                  14.00, '🍗', 3),
    ('炸鸡小食', '劲爆鸡米花（大）', '一口一个',                       13.00, '🍿', 4),

    ('甜品饮料', '百事可乐（中）', '加冰更爽',                          9.00, '🥤', 1),
    ('甜品饮料', '九珍果汁',       '混合果汁',                         12.00, '🧃', 2),
    ('甜品饮料', '拿铁咖啡',       '现磨咖啡',                         16.00, '☕', 3),
    ('甜品饮料', '葡式蛋挞',       '酥皮蛋挞，2 只装',                 11.00, '🥧', 4)
) AS v(cat, name, descr, price, img, so)
JOIN t_category c ON c.name = v.cat
WHERE NOT EXISTS (SELECT 1 FROM t_product p WHERE p.name = v.name AND p.category_id = c.id);


-- =============================================================================
-- 9. 自检：建完表跑一下，确认 7 张表都在、种子数据条数对
-- =============================================================================
-- SELECT table_name FROM information_schema.tables
--  WHERE table_schema = 'public' AND table_name LIKE 't_%' ORDER BY table_name;
-- SELECT (SELECT count(*) FROM t_category) AS 分类,
--        (SELECT count(*) FROM t_product)  AS 餐品,
--        (SELECT count(*) FROM t_user)     AS 用户,
--        (SELECT count(*) FROM t_address)  AS 地址;
