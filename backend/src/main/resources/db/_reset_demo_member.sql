-- =============================================================================
-- 演示数据重置：把 demo 账号恢复成「未开卡」状态，方便现场走一遍开通流程
--
--   psql -h 127.0.0.1 -p 5432 -U postgres -d kfc -f _reset_demo_member.sql
--
-- ⚠ 会员概要走 Redis 缓存（kfc:member:summary:{userId}，TTL 60 秒），
--   直接改库不会让缓存失效 —— 重置后要么等 60 秒，要么手动删 key：
--   redis-cli -h 127.0.0.1 -p 6379 del kfc:member:summary:1
-- =============================================================================
DELETE FROM t_member_card WHERE user_id = 1;
UPDATE t_member
SET coupon_count = 29,
    level        = '普通会员',
    vgold        = 51000,
    achievement  = 6,
    balance      = 0
WHERE user_id = 1;
