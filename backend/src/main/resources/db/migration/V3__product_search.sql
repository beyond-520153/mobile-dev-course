-- =============================================================================
-- V3 —— 餐品搜索：拼音首字母列
-- =============================================================================
-- 目标：让搜索框除了中文，还能接受拼音首字母，例如
--     YWJ  -> 吮指原味鸡
--     JD   -> 劲脆鸡腿堡 / 香辣鸡腿堡（名字里含 jd 的都会命中）
--
-- 实现思路：不在 Java 里现算拼音（会引入 pypinyin4j 之类依赖，且每次请求都要跑一遍），
-- 而是把「名称 -> 首字母串」预先算好存成一列，查询时只走一次 LIKE。
--
-- 本文件由 _kfc_pinyin_sql.py 生成，数据源是 order.kfc.com.cn 的真实菜单
-- （门店 HZ3011，69 个唯一餐品名）。换了菜单要重跑生成脚本 —— 否则这一列会和新菜单对不上。
--
-- 只取餐品「名称」的首字母，不含分类名：分类名的中文匹配由 ProductRepository 的
-- join 条件负责，重复名（如「肉霸堡双人餐」同属两个分类）也因此能共用一条记录。
--
-- 幂等：可重复执行。
-- =============================================================================

ALTER TABLE t_product ADD COLUMN IF NOT EXISTS pinyin_initials VARCHAR(200);

COMMENT ON COLUMN t_product.pinyin_initials IS '餐品名拼音首字母，如 szywj；供搜索用，由 V3 脚本预计算';

-- 按餐品名回填（不按 id：V2 重跑会重新分配主键，按名匹配才能扛住重导入）
UPDATE t_product p
SET pinyin_initials = v.py
FROM (VALUES
    ('乒乒乓乓冰球杯(柠檬味)', 'ppppbqbnmw'),
    ('乒乒乓乓冰球杯4杯(柠檬味)', 'ppppbqbbnmw'),
    ('九珍果汁饮料(冰)', 'jzgzylb'),
    ('人气明星餐随心配4件套', 'rqmxcsxpjt'),
    ('劲爆鸡米花', 'jbjmh'),
    ('劲脆鸡腿堡', 'jcjtb'),
    ('原叶轻乳茶系列', 'yyqrcxl'),
    ('原味冰淇淋花筒', 'ywbqlht'),
    ('原味鸡餐配中薯', 'ywjcpzs'),
    ('原味鸡餐配烤翅', 'ywjcpkc'),
    ('双人便民套餐新奥尔良烤鸡腿堡', 'srbmtcxaelkjtb'),
    ('双人便民套餐香辣鸡腿堡', 'srbmtcxljtb'),
    ('吮指原味鸡(1块/多块装)', 'szywjkdkz'),
    ('吮指原味鸡焖拌饭(泡菜版)', 'szywjmbfpcb'),
    ('四味小食拼盘', 'swxspp'),
    ('四重奏杨枝甘露', 'sczyzgl'),
    ('培根鸡腿肉霸堡', 'pgjtrbb'),
    ('多人团餐', 'drtc'),
    ('天府椒麻香辣粉', 'tfjmxlf'),
    ('拿铁', 'nt'),
    ('新奥尔良烤翅(2块)', 'xaelkck'),
    ('新奥尔良烤鸡腿堡', 'xaelkjtb'),
    ('旅途小食桶(畅选5件)', 'ltxstcxj'),
    ('旅途随心桶(畅选10件)', 'ltsxtcxj'),
    ('旅途随心桶(畅选7件)', 'ltsxtcxj'),
    ('柠檬红茶(中热)', 'nmhczr'),
    ('桂花酸梅汤(大)', 'ghsmtd'),
    ('汁汁双层和牛堡（芝士烟熏风味）', 'zzschnbzsyxfw'),
    ('汁汁和牛堡(芝士烟熏风味)', 'zzhnbzsyxfw'),
    ('汁汁和牛堡三件套', 'zzhnbsjt'),
    ('清润三梨饮（中|热）', 'qrslyzr'),
    ('满杯生椰拿铁', 'mbsynt'),
    ('炸鸡爆柠套餐', 'zjbntc'),
    ('热辣香骨鸡(3块)', 'rlxgjk'),
    ('爆汁三柠气泡美式', 'bzsnqpms'),
    ('爆汁三柠茶(冰)', 'bzsncb'),
    ('爆汁三柠饮(大)', 'bzsnyd'),
    ('爆汁苹果饮(大)', 'bzpgyd'),
    ('牛堡人气餐', 'nbrqc'),
    ('牛奶(热)', 'nnr'),
    ('牛牛双人餐', 'nnsrc'),
    ('现磨牛奶雪顶®咖啡', 'xmnnxdkf'),
    ('琥珀三柠气泡茶(大)', 'hpsnqpcd'),
    ('琥珀苹果气泡茶(大)', 'hppgqpcd'),
    ('百事可乐(冰)', 'bsklb'),
    ('百事无糖可乐(冰)', 'bswtklb'),
    ('红苹果热美式', 'hpgrms'),
    ('红豆派(1只)', 'hdpz'),
    ('经典圣代系列', 'jdsdxl'),
    ('经典香浓玉米饮', 'jdxnymy'),
    ('美式', 'ms'),
    ('美式烧烤风味酱', 'msskfwj'),
    ('老北京鸡肉卷', 'lbjjrj'),
    ('肉霸堡人气餐', 'rbbrqc'),
    ('肉霸堡单人餐', 'rbbdrc'),
    ('肉霸堡双人餐', 'rbbsrc'),
    ('芙蓉荟蔬汤', 'frhst'),
    ('苹果气泡美式', 'pgqpms'),
    ('葡式蛋挞(1只/多只装)', 'psdtzdzz'),
    ('薄脆金沙鸡翅(2块)', 'bcjsjck'),
    ('薯条', 'st'),
    ('避风塘风味粉', 'bftfwf'),
    ('醇香土豆泥', 'cxtdn'),
    ('香菜牛肉风味粉', 'xcnrfwf'),
    ('香辣孜然风味粉', 'xlzrfwf'),
    ('香辣鸡翅(2块)', 'xljck'),
    ('香辣鸡腿堡', 'xljtb'),
    ('鲜柠气泡水(无糖)', 'xnqpswt'),
    ('黄金鸡块(5块)', 'hjjkk')
) AS v(name, py)
WHERE p.name = v.name;

-- 没被覆盖到的残留（比如手工加过的餐品）统一清成 NULL，避免存着过期首字母
UPDATE t_product SET pinyin_initials = NULL WHERE pinyin_initials IS NULL;
