DELETE FROM t_member_card WHERE user_id = 1;
UPDATE t_member
SET coupon_count = 29,
    level        = '普通会员',
    vgold        = 51000,
    achievement  = 6,
    balance      = 0
WHERE user_id = 1;
