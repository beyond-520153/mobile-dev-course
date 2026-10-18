-- =============================================================================
-- 大神卡权益规则 + 订单优惠结算
-- 数据库：PostgreSQL 17      库名：kfc      执行方式：
--   psql -h 127.0.0.1 -p 5432 -U postgres -d kfc -f V5__member_benefit.sql
--
-- 两张新表：
--   t_benefit_rule   权益规则（数据驱动：折扣率 / 立减 / 特价 / 免配送费，按时段与每日限次）
--   t_benefit_usage  权益使用流水（用户 + 规则 + 日期唯一，控制「每日 1 次」）
--
-- 订单表补四列：
--   delivery_fee     外送费（到店自取为 0）
--   discount_amount  权益优惠合计
--   benefit_codes    本单用掉的规则编码，逗号分隔（取消订单时按它归还次数）
--   benefit_detail   优惠文案，直接给前端展示
--
-- 规则来自官方 2026 年大神卡权益（早餐两件套 6 折 / 每日 1 杯咖啡 10 元 /
-- 下午茶时段两件套 6 折 / 人气套餐立减 / 外送免配送费），映射到本项目菜单分类。
-- 官方规则随时会调，改数据即可，不用改代码。
-- =============================================================================

-- 需要重建时手工执行（默认注释，避免误删数据）
-- DROP TABLE IF EXISTS t_benefit_usage CASCADE;
-- DROP TABLE IF EXISTS t_benefit_rule  CASCADE;


-- =============================================================================
-- 1. 权益规则
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_benefit_rule (
    id               BIGSERIAL      PRIMARY KEY,
    code             VARCHAR(32)    NOT NULL,                    -- GOD_COFFEE_10 / GOD_FREE_DELIVERY ...
    card_type        VARCHAR(20)    NOT NULL,                    -- GOD 大神卡 / COFFEE 咖啡卡
    name             VARCHAR(50)    NOT NULL,                    -- 「每日 1 杯指定咖啡 10 元」
    benefit_type     VARCHAR(20)    NOT NULL,                    -- PERCENT_OFF 折扣 / AMOUNT_OFF 立减 / FIXED_PRICE 特价 / FREE_DELIVERY 免配送费
    scope_type       VARCHAR(20)    NOT NULL DEFAULT 'CATEGORY', -- CATEGORY 按分类 / ALL 全场
    scope_ids        VARCHAR(200),                               -- 分类 id，逗号分隔
    min_quantity     INTEGER        NOT NULL DEFAULT 1,          -- 需凑够几件（「两件套」= 2）
    threshold_amount NUMERIC(10,2)  NOT NULL DEFAULT 0,          -- 商品金额门槛
    discount_value   NUMERIC(10,2)  NOT NULL DEFAULT 0,          -- 折扣率 0.60 / 立减 5.00 / 特价 10.00
    max_discount     NUMERIC(10,2),                              -- 单次优惠封顶，NULL 表示不封顶
    start_time       TIME,                                       -- 生效时段起，NULL 表示全天
    end_time         TIME,
    daily_limit      INTEGER        NOT NULL DEFAULT 1,          -- 每人每日可用次数
    pickup_types     VARCHAR(40)    NOT NULL DEFAULT 'PICKUP,DELIVERY',
    description      VARCHAR(255),                               -- 权益说明，前端展示
    sort_order       INTEGER        NOT NULL DEFAULT 0,          -- 计算顺序：越小越先算
    status           INTEGER        NOT NULL DEFAULT 1,          -- 1 生效 0 停用
    created_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ    NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_benefit_rule IS '会员卡权益规则表（数据驱动，改规则不用改代码）';

CREATE UNIQUE INDEX IF NOT EXISTS uk_benefit_code ON t_benefit_rule (code);
CREATE INDEX IF NOT EXISTS idx_benefit_card ON t_benefit_rule (card_type, status, sort_order);


-- =============================================================================
-- 2. 权益使用流水（每日限次的依据）
-- =============================================================================
CREATE TABLE IF NOT EXISTS t_benefit_usage (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES t_user (id) ON DELETE CASCADE,
    rule_code   VARCHAR(32)  NOT NULL,
    use_date    DATE         NOT NULL,                           -- 自然日（东八区）
    used_count  INTEGER      NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON TABLE t_benefit_usage IS '权益使用流水：用户 + 规则 + 日期唯一，用来卡「每日 N 次」';

CREATE UNIQUE INDEX IF NOT EXISTS uk_usage_user_rule_day ON t_benefit_usage (user_id, rule_code, use_date);


-- =============================================================================
-- 3. 订单表补优惠字段（幂等，重复执行不报错）
-- =============================================================================
ALTER TABLE t_order ADD COLUMN IF NOT EXISTS delivery_fee    NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE t_order ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE t_order ADD COLUMN IF NOT EXISTS benefit_codes   VARCHAR(200);
ALTER TABLE t_order ADD COLUMN IF NOT EXISTS benefit_detail  VARCHAR(500);

COMMENT ON COLUMN t_order.delivery_fee    IS '外送费（到店自取为 0）';
COMMENT ON COLUMN t_order.discount_amount IS '会员卡权益优惠合计';
COMMENT ON COLUMN t_order.benefit_codes   IS '本单使用的权益规则编码，逗号分隔';
COMMENT ON COLUMN t_order.benefit_detail  IS '优惠文案，前端直接展示';


-- =============================================================================
-- 4. 种子规则
--    分类 id 对照：6 人气热卖 / 8 桶多人餐 / 13 饮品 / 14 金奖豆K咖啡 /
--                  15 蛋挞甜品 / 16 冰淇淋 / 18 多人团餐
-- =============================================================================
INSERT INTO t_benefit_rule
    (code, card_type, name, benefit_type, scope_type, scope_ids, min_quantity,
     threshold_amount, discount_value, max_discount, start_time, end_time,
     daily_limit, pickup_types, description, sort_order, status)
VALUES
    ('GOD_BREAKFAST_40OFF', 'GOD', '早餐两件套 6 折', 'PERCENT_OFF', 'CATEGORY', '13,15',
     2, 0, 0.60, 20.00, '07:00', '10:30', 1, 'PICKUP,DELIVERY',
     '每日 1 次：早餐时段（07:00-10:30）指定两件套 6 折，单笔最高减 20 元', 1, 1),

    ('GOD_COFFEE_10', 'GOD', '每日 1 杯咖啡 10 元', 'FIXED_PRICE', 'CATEGORY', '14',
     1, 0, 10.00, NULL, NULL, NULL, 1, 'PICKUP,DELIVERY',
     '每日 1 次：金奖豆K咖啡指定大杯 10 元，原价低于 10 元的餐品不参与', 2, 1),

    ('GOD_DESSERT_40OFF', 'GOD', '下午茶两件套 6 折', 'PERCENT_OFF', 'CATEGORY', '15,16',
     2, 0, 0.60, 20.00, '14:00', '17:00', 1, 'PICKUP,DELIVERY',
     '每日 1 次：下午茶时段（14:00-17:00）指定两件套 6 折，单笔最高减 20 元', 3, 1),

    ('GOD_COMBO_MINUS5', 'GOD', '人气套餐立减 5 元', 'AMOUNT_OFF', 'CATEGORY', '6,8,18',
     1, 30.00, 5.00, NULL, NULL, NULL, 1, 'PICKUP,DELIVERY',
     '每日 1 次：人气热卖 / 桶多人餐 / 多人团餐，单笔满 30 元立减 5 元', 4, 1),

    ('GOD_FREE_DELIVERY', 'GOD', '外送免配送费', 'FREE_DELIVERY', 'ALL', NULL,
     1, 29.00, 0, NULL, NULL, NULL, 2, 'DELIVERY',
     '每天最多 2 次：外送订单满 29 元免 9 元配送费，仅限官方渠道下单', 5, 1),

    ('COFFEE_DAILY_MINUS8', 'COFFEE', '咖啡卡每日 1 杯立减 8 元', 'AMOUNT_OFF', 'CATEGORY', '14',
     1, 0, 8.00, NULL, NULL, NULL, 1, 'PICKUP,DELIVERY',
     '每日 1 次：咖啡卡会员指定咖啡立减 8 元，与大神卡同日不重复抵扣同一杯', 6, 1)
ON CONFLICT (code) DO UPDATE
    SET card_type        = EXCLUDED.card_type,
        name             = EXCLUDED.name,
        benefit_type     = EXCLUDED.benefit_type,
        scope_type       = EXCLUDED.scope_type,
        scope_ids        = EXCLUDED.scope_ids,
        min_quantity     = EXCLUDED.min_quantity,
        threshold_amount = EXCLUDED.threshold_amount,
        discount_value   = EXCLUDED.discount_value,
        max_discount     = EXCLUDED.max_discount,
        start_time       = EXCLUDED.start_time,
        end_time         = EXCLUDED.end_time,
        daily_limit      = EXCLUDED.daily_limit,
        pickup_types     = EXCLUDED.pickup_types,
        description      = EXCLUDED.description,
        sort_order       = EXCLUDED.sort_order,
        status           = EXCLUDED.status,
        updated_at       = now();
