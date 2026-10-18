-- =============================================================================
-- 会员模块（WOW 会员中心 / 大神卡）
-- 数据库：PostgreSQL 17      库名：kfc      执行方式：
--   psql -h 127.0.0.1 -p 5432 -U postgres -d kfc -f V4__member.sql
--
-- 三张表：
--   t_member       会员账户（一人一条，与 t_user 一对一）+ V金 / 卡券 / 余额 / 成就
--   t_member_plan  可售套餐档位（大神卡月/季/年 + 咖啡卡 30 天）
--   t_member_card  已开通的会员卡（一个用户可同时持有多张，按类型区分）
--
-- 与前面脚本同样的约定：金额 NUMERIC(10,2)、时间 TIMESTAMPTZ、状态 INTEGER、
-- 时间戳由应用层 @PrePersist / @PreUpdate 维护，这里只给 DEFAULT 兜底。
-- =============================================================================

-- 需要重建时手工执行（默认注释，避免误删数据）
-- DROP TABLE IF EXISTS t_member_card CASCADE;
-- DROP TABLE IF EXISTS t_member_plan CASCADE;
-- DROP TABLE IF EXISTS t_member      CASCADE;


-- =============================================================================
-- 1. 会员账户
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_member (
    id           BIGSERIAL     PRIMARY KEY,
    user_id      BIGINT        NOT NULL REFERENCES t_user (id) ON DELETE CASCADE,
    member_no    VARCHAR(32)   NOT NULL,                     -- 会员号，如 8000 0113
    nickname     VARCHAR(50),                                -- 会员昵称，为空时回退 t_user.nickname
    level        VARCHAR(20)   NOT NULL DEFAULT '普通会员',   -- 普通会员 / WOW会员
    vgold        INTEGER       NOT NULL DEFAULT 0,           -- V金（消费 1 元 = 1 V金）
    coupon_count INTEGER       NOT NULL DEFAULT 0,           -- 卡券张数
    balance      NUMERIC(10,2) NOT NULL DEFAULT 0,           -- 账户余额
    achievement  INTEGER       NOT NULL DEFAULT 0,           -- 已点亮成就数
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_member IS '会员账户表（与 t_user 一对一）';

CREATE UNIQUE INDEX IF NOT EXISTS uk_member_user ON t_member (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS uk_member_no   ON t_member (member_no);


-- =============================================================================
-- 2. 可售套餐档位
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_member_plan (
    id            BIGSERIAL     PRIMARY KEY,
    code          VARCHAR(32)   NOT NULL,                    -- GOD_MONTH / GOD_SEASON / GOD_YEAR / COFFEE_30
    card_type     VARCHAR(20)   NOT NULL,                    -- GOD 大神卡 / COFFEE 咖啡卡
    name          VARCHAR(50)   NOT NULL,                    -- 月卡 / 季卡 / 年卡 / 咖啡卡 · 30天
    months        INTEGER       NOT NULL,                    -- 有效月数，开卡时用来算到期时间
    price         NUMERIC(10,2) NOT NULL,                    -- 现价
    origin_price  NUMERIC(10,2) NOT NULL,                    -- 划线原价
    privilege_num INTEGER       NOT NULL DEFAULT 0,          -- 特权条数
    sort_order    INTEGER       NOT NULL DEFAULT 0,          -- 越小越靠前
    status        INTEGER       NOT NULL DEFAULT 1,          -- 1 在售 0 下架
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_member_plan IS '会员卡可售档位表';

CREATE UNIQUE INDEX IF NOT EXISTS uk_plan_code ON t_member_plan (code);
CREATE INDEX IF NOT EXISTS idx_plan_type ON t_member_plan (card_type, status, sort_order);


-- =============================================================================
-- 3. 已开通的会员卡
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_member_card (
    id          BIGSERIAL     PRIMARY KEY,
    user_id     BIGINT        NOT NULL REFERENCES t_user (id) ON DELETE CASCADE,
    plan_id     BIGINT        NOT NULL REFERENCES t_member_plan (id),
    card_type   VARCHAR(20)   NOT NULL,                      -- 冗余一份，列表展示不必再关联档位表
    card_name   VARCHAR(50)   NOT NULL,
    card_no     VARCHAR(32)   NOT NULL,                      -- 卡号，支付/核销用
    start_at    TIMESTAMPTZ   NOT NULL,
    expire_at   TIMESTAMPTZ   NOT NULL,
    status      VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE',     -- ACTIVE 生效 / EXPIRED 已过期
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_member_card IS '已开通的会员卡（同一用户可同时持有多张）';

CREATE INDEX IF NOT EXISTS idx_card_user   ON t_member_card (user_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uk_card_no ON t_member_card (card_no);


-- =============================================================================
-- 4. 种子数据：四个档位（价格照官方截图）
-- =============================================================================
INSERT INTO t_member_plan (code, card_type, name, months, price, origin_price, privilege_num, sort_order, status)
VALUES
    ('GOD_SEASON', 'GOD',    '季卡',           3,  30.00,  38.00, 11, 1, 1),
    ('GOD_YEAR',   'GOD',    '年卡',          12, 100.00, 108.00, 11, 2, 1),
    ('GOD_MONTH',  'GOD',    '月卡',           1,  19.00,  25.00, 11, 3, 1),
    ('COFFEE_30',  'COFFEE', '咖啡卡 · 30天',  1,  12.00,  15.00,  8, 4, 1)
ON CONFLICT (code) DO UPDATE
    SET name          = EXCLUDED.name,
        months        = EXCLUDED.months,
        price         = EXCLUDED.price,
        origin_price  = EXCLUDED.origin_price,
        privilege_num = EXCLUDED.privilege_num,
        sort_order    = EXCLUDED.sort_order,
        updated_at    = now();


-- =============================================================================
-- 5. 种子数据：给已有用户补会员账户（会员号 = 80000000 + id * 113，与前端展示口径一致）
-- =============================================================================
INSERT INTO t_member (user_id, member_no, level)
SELECT u.id,
       (80000000 + u.id * 113)::VARCHAR(32),
       '普通会员'
FROM t_user u
ON CONFLICT (user_id) DO NOTHING;

-- 演示账号 demo 给一点初始数据，方便前端一登录就能看到非零的数值
UPDATE t_member m
SET vgold        = 51000,
    coupon_count = 29,
    balance      = 0.00,
    achievement  = 6,
    updated_at   = now()
FROM t_user u
WHERE u.id = m.user_id
  AND u.username = 'demo'
  AND m.vgold = 0
  AND m.coupon_count = 0;
