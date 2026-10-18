import { Constants, Theme } from '../common/Constants';
import { Icons, VectorIcon } from '../components/VectorIcon';
import { EntryTabBar } from '../components/EntryTabBar';
import { ProductApi } from '../api/ProductApi';
import { Category } from '../model/Category';
import { Product } from '../model/Product';
import { UserApi } from '../api/UserApi';
import { MemberApi } from '../api/MemberApi';
import { MemberSummary } from '../model/Member';
import { CartViewModel } from '../viewmodel/CartViewModel';

/**
 * 首页陈列位配置：角标与价格照肯德基首页写，图与名称取真实菜单
 * keys 是候选关键词，在餐品名里做包含匹配；匹配不到就按下标兜底。
 */
interface HotConf {
  keys: string[];
  badge: string;
  price: string;
  origin: string;
  from: boolean;
  idx: number;
}

/** 陈列卡渲染数据 */
interface HotCard {
  name: string;
  image: string;
  price: string;
  origin: string;
  badge: string;
  from: boolean;
}

/** 取餐通道 */
interface Channel {
  label: string;
  type: string;
}

/** 顶栏频道：只切高亮，菜单数据仍是肯德基那一套（固定四个品牌，不横滑） */
const CHANNEL_TABS: string[] = ['肯德基', '肯律轻食', '肯悦咖啡', '炸鸡兄弟'];

/**
 * 取餐方式入口页（应用启动页）
 *
 * 版式完全照肯德基小程序首页重绘，自上而下：
 *   红色渐变头部（城市天际线 + 门店 + 外卖骑手 + 车速取汽车，Canvas 手绘）
 *   → 三个取餐通道（外送到家 / 到店自取 / 开车速取）
 *   → 四个功能圆图标 → 会员卡（上校头像）
 *   → APP热卖 / 大神卡专区 → 两列商品网格 → 两张券卡
 *   → 深色底部 tab（首页 / 百胜出品 / AI点餐 / 大神卡 / 会员中心）
 *
 * 顶部频道栏（肯德基 / 肯律轻食 / 肯悦咖啡 / 炸鸡兄弟 …）按参考图做成
 * 红底上一条半透明胶囊 + 右端圆钮；底部 tab 里「大神卡」「会员中心」
 * 已接真实页面，其余三项仍是占位提示。
 *
 * 三个取餐通道进入的是同一个点餐页（pages/Index），只把选择写进
 * AppStorage 的 pickupType，点餐页顶部据此显示取餐方式文案。
 */
@Entry
@Component
struct EntryPage {

  /** 取餐方式，点餐页顶部据此显示标签 */
  @StorageLink('pickupType') pickupType: string = 'PICKUP';

  /** 登录用户（入口页先登录一次，点餐页就不再重复登录） */
  @StorageLink('userId') userId: number = 0;

  /** 会员概要：会员卡上的 V金 / 卡券 / 余额 */
  @State member: MemberSummary | null = null;

  /** 当前陈列 tab：HOT=APP热卖，VIP=大神卡专区 */
  @State hotTab: string = 'HOT';

  /** 顶栏当前频道 */
  @State channel: string = '肯德基';

  /** 陈列卡（来自真实菜单） */
  @State cards: HotCard[] = [];

  /** 可用餐品池，切 tab 时重新挑选 */
  private pool: Product[] = [];

  /** 头部插画画布 */
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  /** 频道条横向滚动控制器 */
  private chScroller: Scroller = new Scroller();

  /** 画布缩放系数与偏移（设计稿坐标系 390 x 214） */
  private sc: number = 1;
  private ox: number = 0;
  private oy: number = 0;

  /** 三个取餐通道 */
  private readonly CHANNELS: Channel[] = [
    { label: '外送到家', type: 'DELIVERY' },
    { label: '到店自取', type: 'PICKUP' },
    { label: '开车速取', type: 'DRIVE' }
  ];

  aboutToAppear(): void {
    if (this.pickupType.length === 0) {
      this.pickupType = 'PICKUP';
    }
    this.loadPool();
    this.initMember();
  }

  onPageShow(): void {
    // 从大神卡页开完卡回来，会员卡上的 V金/卡券 要跟着变
    this.loadMember();
  }

  /* ---------------------------- 数据 ---------------------------- */

  /**
   * 入口页先把演示账号登一次，后面的点餐页/购物车/会员页就都有 userId 了
   *
   * 之前登录只写在点餐页里，导致入口页这张会员卡拿不到真实数据，只能写死
   * 「5.1万 / 30 张 / 0 元」，和 WOW 页对不上。这里补登录，两页同源。
   */
  private async initMember(): Promise<void> {
    if (this.userId <= 0) {
      try {
        const user = await UserApi.login(Constants.DEMO_USERNAME, Constants.DEMO_PASSWORD);
        CartViewModel.setCurrentUserId(user.id);
      } catch (err) {
        console.error('入口页自动登录演示账号失败: ' + JSON.stringify(err));
        return;
      }
    }
    await this.loadMember();
  }

  private async loadMember(): Promise<void> {
    if (this.userId <= 0) {
      return;
    }
    try {
      this.member = await MemberApi.summary(this.userId);
    } catch (err) {
      this.member = null;
    }
  }

  /** V金满 1 万按「万」显示，与 WOW 页口径一致 */
  private vgoldText(): string {
    if (this.member === null) {
      return '--';
    }
    const v: number = this.member.vgold;
    return v >= 10000 ? (v / 10000).toFixed(1) + '万' : v.toString();
  }

  private couponText(): string {
    return this.member === null ? '--' : this.member.couponCount.toString();
  }

  private balanceText(): string {
    return this.member === null ? '--' : Number(this.member.balance).toFixed(0);
  }

  private loadPool(): void {
    ProductApi.listCategories()
      .then((list: Category[]) => {
        const pool: Product[] = [];
        list.forEach((c: Category) => {
          c.products.forEach((p: Product) => {
            if (p.image !== undefined && p.image.length > 0) {
              pool.push(p);
            }
          });
        });
        this.pool = pool;
        this.cards = this.buildCards(this.hotTab);
      })
      .catch(() => {
        // 首页不阻塞：拉不到菜单时陈列区留空，点餐页会自己重试
      });
  }

  private confOf(tab: string): HotConf[] {
    if (tab === 'VIP') {
      return [
        { keys: ['生椰'], badge: '', price: '9.9', origin: '22', from: false, idx: 3 },
        { keys: ['拿铁'], badge: '', price: '9.9', origin: '19', from: false, idx: 9 },
        { keys: ['美式'], badge: '', price: '9.9', origin: '18', from: false, idx: 15 },
        { keys: ['三柠', '气泡'], badge: '', price: '9.9', origin: '19', from: false, idx: 21 }
      ];
    }
    return [
      { keys: ['周末疯狂', '疯狂拼', '拼'], badge: '4件299', price: '29.9', origin: '63.6', from: true, idx: 0 },
      { keys: ['三柠', '气泡'], badge: '', price: '9.9', origin: '19', from: false, idx: 12 },
      { keys: ['周末疯狂', '疯狂拼', '拼', '桶'], badge: '8件499', price: '49.9', origin: '127', from: true, idx: 1 },
      { keys: ['生椰', '拿铁'], badge: '', price: '9.9', origin: '22', from: false, idx: 40 }
    ];
  }

  /**
   * 按关键词挑一个餐品，挑不到就按下标取模
   *
   * used 是已占用的**餐品名**：四个陈列位必须是四款不同餐品。
   * 不能按 id 去重 —— 真实菜单里同一款会挂在两个分类下
   * （「四味小食拼盘」在人气热卖 id=27、炸鸡小食 id=42），
   * 按 id 挡不住，页面上会并排出现两张一模一样的卡（预览页踩过这个坑）。
   */
  private pick(c: HotConf, extra: number, used: string[]): Product | undefined {
    if (this.pool.length === 0) {
      return undefined;
    }
    let src: Product[] = this.pool.filter((p: Product) => used.indexOf(p.name) < 0);
    if (src.length === 0) {
      src = this.pool;
    }
    for (let i = 0; i < c.keys.length; i++) {
      const key = c.keys[i];
      const hit: Product | undefined = src.find((p: Product) => p.name.indexOf(key) >= 0);
      if (hit !== undefined) {
        return hit;
      }
    }
    return src[(c.idx + extra) % src.length];
  }

  private buildCards(tab: string): HotCard[] {
    const conf = this.confOf(tab);
    const used: string[] = [];
    const out: HotCard[] = [];
    conf.forEach((c: HotConf, i: number) => {
      const p = this.pick(c, i * 7, used);
      if (p !== undefined) {
        used.push(p.name);
        out.push({
          name: p.name,
          image: p.image !== undefined ? p.image : '',
          price: c.price,
          origin: c.origin,
          badge: c.badge,
          from: c.from
        });
      }
    });
    return out;
  }

  private imgUrl(image: string): string {
    if (image.startsWith('http')) {
      return image;
    }
    return image.startsWith('/') ? Constants.BASE_URL + image : '';
  }

  private notify(msg: string): void {
    // showToast 在弹窗被系统抢占时会抛异常，入口页的占位提示不该因此崩掉页面
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      console.warn('showToast failed: ' + JSON.stringify(e));
    }
  }

  /** 选好取餐方式 → 进点餐页（三处入口同一个页面） */
  private enter(type: string): void {
    this.pickupType = type;
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/Index' });
    } catch (e) {
      console.error('pushUrl pages/Index failed: ' + JSON.stringify(e));
    }
  }

  /* ------------------------- 头部插画（Canvas） ------------------------- */

  private X(v: number): number {
    return this.ox + v * this.sc;
  }

  private Y(v: number): number {
    return this.oy + v * this.sc;
  }

  private poly(pts: number[][], color: string, dy: number): void {
    const c = this.ctx;
    c.beginPath();
    c.moveTo(this.X(pts[0][0]), this.Y(pts[0][1] + dy));
    for (let i = 1; i < pts.length; i++) {
      c.lineTo(this.X(pts[i][0]), this.Y(pts[i][1] + dy));
    }
    c.closePath();
    c.fillStyle = color;
    c.fill();
  }

  private box(x: number, y: number, w: number, h: number, color: string): void {
    const c = this.ctx;
    c.fillStyle = color;
    c.fillRect(this.X(x), this.Y(y), w * this.sc, h * this.sc);
  }

  private dot(cx: number, cy: number, r: number, color: string): void {
    const c = this.ctx;
    c.beginPath();
    c.arc(this.X(cx), this.Y(cy), r * this.sc, 0, Math.PI * 2);
    c.closePath();
    c.fillStyle = color;
    c.fill();
  }

  /** 半圆帽（上校头发与骑手头盔） */
  private halfDot(cx: number, cy: number, r: number, color: string): void {
    const c = this.ctx;
    c.beginPath();
    c.arc(this.X(cx), this.Y(cy), r * this.sc, Math.PI, Math.PI * 2);
    c.closePath();
    c.fillStyle = color;
    c.fill();
  }

  private line(x1: number, y1: number, x2: number, y2: number, color: string, width: number): void {
    const c = this.ctx;
    c.beginPath();
    c.moveTo(this.X(x1), this.Y(y1));
    c.lineTo(this.X(x2), this.Y(y2));
    c.strokeStyle = color;
    c.lineWidth = width * this.sc;
    c.lineCap = 'round';
    c.stroke();
  }

  private txt(s: string, x: number, y: number, size: number, color: string, bold: boolean): void {
    const c = this.ctx;
    c.font = (bold ? 'bold ' : '') + Math.round(size * this.sc) + 'px sans-serif';
    c.fillStyle = color;
    c.textAlign = 'center';
    c.fillText(s, this.X(x), this.Y(y));
  }

  private drawHero(): void {
    const c = this.ctx;
    const w = c.width;
    const h = c.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const sc = Math.min(w / 390, h / 214);
    this.sc = sc;
    this.ox = (w - 390 * sc) / 2;
    this.oy = h - 214 * sc;
    c.clearRect(0, 0, w, h);

    this.drawSkyline();
    this.drawScene();
  }

  /** 城市天际线：白色半透明剪影，垫在门店后面（设计稿 y 整体下移 84） */
  private drawSkyline(): void {
    const dy = 84;
    const left: number[][] = [
      [-4, 130], [-4, 74], [10, 74], [10, 56], [20, 56], [20, 44], [24, 30], [28, 44],
      [28, 54], [36, 54], [36, 72], [44, 72], [44, 52], [54, 52], [54, 68], [62, 68],
      [62, 86], [72, 79], [82, 86], [82, 64], [90, 64], [90, 90], [98, 90], [98, 72],
      [108, 72], [108, 96], [118, 96], [118, 130]
    ];
    const right: number[][] = [
      [286, 130], [286, 82], [294, 82], [294, 66], [298, 52], [302, 66], [302, 80],
      [310, 80], [310, 98], [320, 98], [320, 70], [328, 70], [328, 90], [338, 90],
      [338, 76], [348, 76], [348, 100], [356, 100], [356, 84], [366, 84], [366, 66],
      [376, 66], [376, 94], [384, 94], [384, 78], [394, 78], [394, 130]
    ];
    this.poly(left, 'rgba(255,255,255,0.72)', dy);
    this.poly(right, 'rgba(255,255,255,0.72)', dy);
    this.box(0, 128.6 + dy, 390, 1.6, 'rgba(255,255,255,0.55)');
  }

  /** 门店 + 外卖骑手 + 车速取小屋 + 汽车 */
  private drawScene(): void {
    // 地面投影
    this.box(84, 208, 232, 6, 'rgba(0,0,0,0.09)');
    this.box(22, 204, 92, 5, 'rgba(0,0,0,0.09)');
    this.box(288, 204, 96, 5, 'rgba(0,0,0,0.09)');

    /* ---- 门店 ---- */
    this.poly([[262, 90], [284, 84], [284, 206], [262, 211]], '#F1F1F1', 0);
    this.poly([[262, 80], [284, 74], [284, 84], [262, 90]], '#D4001F', 0);
    this.box(126, 76, 142, 9, '#E4002B');
    this.box(132, 85, 130, 36, '#FFFFFF');
    this.txt('KFC', 176, 113, 21, '#E4002B', true);

    // 圆形上校 logo
    this.dot(236, 103, 15.5, '#FFFFFF');
    this.halfDot(236, 102.4, 8.5, '#EFEFEF');
    this.box(228.5, 101.4, 15, 4.4, '#F6D3B4');
    this.box(229.4, 105.6, 13.2, 4.4, '#F6D3B4');
    this.dot(232, 104.2, 1.15, '#3A3A3A');
    this.dot(240, 104.2, 1.15, '#3A3A3A');
    this.box(230.4, 108.2, 11.2, 2.2, '#FFFFFF');
    this.poly([[236, 111.8], [233.3, 113.4], [233.8, 110.1]], '#E4002B', 0);
    this.poly([[236, 111.8], [238.7, 113.4], [238.2, 110.1]], '#E4002B', 0);

    // 楼体与玻璃
    this.box(132, 121, 130, 88, '#FBFBFB');
    this.box(132, 121, 130, 4, '#E4002B');
    this.box(141, 136, 52, 64, '#B5E1EE');
    this.line(141, 168, 193, 168, '#FFFFFF', 2.4);
    this.line(167, 136, 167, 200, '#FFFFFF', 2.4);
    this.box(199, 132, 56, 77, '#B5E1EE');
    this.line(227, 132, 227, 209, '#FFFFFF', 2.4);
    this.line(199, 148, 227, 148, '#FFFFFF', 1.8);
    this.line(199, 164, 227, 164, '#FFFFFF', 1.8);
    this.box(126, 209, 142, 6, '#ECECEC');

    /* ---- 外卖骑手 ---- */
    this.dot(40, 198, 10, '#2E2E2E');
    this.dot(40, 198, 3.6, '#8A8A8A');
    this.dot(92, 198, 10, '#2E2E2E');
    this.dot(92, 198, 3.6, '#8A8A8A');
    this.poly([[40, 198], [52, 183], [78, 183], [92, 198]], '#E4002B', 0);
    this.box(20, 156, 34, 30, '#E4002B');
    this.txt('KFC', 37, 176, 10, '#FFFFFF', true);
    this.line(64, 192, 78, 195, '#B3001F', 5);
    this.poly([[66, 190], [72, 166], [84, 165], [88, 190]], '#E4002B', 0);
    this.line(82, 168, 91, 179, '#E4002B', 5.5);
    this.dot(92, 180, 3, '#F3C6A2');
    this.dot(77, 155, 8.8, '#F3C6A2');
    this.halfDot(77, 155.2, 8.6, '#E4002B');
    this.line(68.4, 155.8, 85.6, 155.8, '#C40022', 1.3);

    /* ---- 车速取小屋 ---- */
    this.box(300, 132, 76, 28, '#3A3A3A');
    this.poly([[294, 132], [312, 118], [376, 118], [384, 132]], '#E4002B', 0);
    this.txt('车速取', 338, 151, 12, '#FFFFFF', true);
    this.box(306, 160, 3, 12, '#9A9A9A');
    this.box(368, 160, 3, 12, '#9A9A9A');

    /* ---- 红色汽车 ---- */
    this.poly([[284, 200], [284, 192], [289, 186], [304, 184], [316, 172], [346, 172],
      [358, 184], [373, 186], [378, 192], [378, 200]], '#E4002B', 0);
    this.poly([[318, 185], [325, 175], [345, 175], [352, 185]], '#CFEAF3', 0);
    this.line(284, 190, 362, 190, '#C40022', 1.2);
    this.box(283, 193, 5, 4, '#FFD05B');
    this.dot(304, 205, 9, '#2E2E2E');
    this.dot(304, 205, 3.2, '#9E9E9E');
    this.dot(356, 205, 9, '#2E2E2E');
    this.dot(356, 205, 3.2, '#9E9E9E');
  }

  /* ---------------------------- 分块 UI ---------------------------- */

  /**
   * 0. 顶栏频道条
   *
   * 红底上一条半透明白胶囊（50% 白），选中项是纯白胶囊 + 红字；
   * 胶囊右端用 26vp 渐变收到圆形菜单钮，暗示还有更多品牌可以横滑。
   * 点击只切高亮与 hero 语义，菜单数据始终是肯德基那一套。
   */
  @Builder
  channelBar() {
    Row() {
      Stack({ alignContent: Alignment.End }) {
        Scroll(this.chScroller) {
          Row() {
            ForEach(CHANNEL_TABS, (c: string) => {
              Text(c)
                .fontSize(13)
                .fontWeight(this.channel === c ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.channel === c ? Theme.PRIMARY : '#FFFFFF')
                .height(30)
                .padding({ left: this.channel === c ? 11 : 12, right: this.channel === c ? 11 : 12 })
                .borderRadius(15)
                .backgroundColor(this.channel === c ? '#FFFFFF' : Color.Transparent)
                .onClick(() => {
                  this.channel = c;
                })
            }, (c: string) => c)
          }
          .height('100%')
          .alignItems(VerticalAlign.Center)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')

        // 右端渐隐：滑出去的频道淡出，而不是被硬切一刀
        Text('')
          .width(26)
          .height('100%')
          .linearGradient({
            angle: 90,
            colors: [['#00F18095', 0.0], ['#FFF18095', 1.0]]
          })
      }
      .layoutWeight(1)
      .height(34)
      .borderRadius(17)
      .backgroundColor('#F18095')
      .clip(true)

      // 右端圆钮（三横线）
      Column() {
        Text('').width(15).height(2).borderRadius(1).backgroundColor('#FFFFFF')
        Text('')
          .width(15)
          .height(2)
          .borderRadius(1)
          .backgroundColor('#FFFFFF')
          .margin({ top: 3 })
        Text('')
          .width(15)
          .height(2)
          .borderRadius(1)
          .backgroundColor('#FFFFFF')
          .margin({ top: 3 })
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor('#F0758C')
      .justifyContent(FlexAlign.Center)
      .margin({ left: 11 })
      .onClick(() => {
        this.notify('更多品牌正在接入中');
      })
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 12 })
    .backgroundColor(Theme.PRIMARY)
    .alignItems(VerticalAlign.Center)
  }

  /** 1. 红色头部 */
  @Builder
  hero() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Text('')
        .width('100%')
        .height(200)
        .linearGradient({
          angle: 180,
          colors: [['#E4002B', 0.0], ['#DC0027', 0.58], ['#C6001F', 1.0]]
        })

      Canvas(this.ctx)
        .width('100%')
        .height(200)
        .onReady(() => {
          this.drawHero();
        })
    }
    .width('100%')
    .height(200)
  }

  /** 2. 三个取餐通道 */
  @Builder
  channelRow() {
    Row() {
      ForEach(this.CHANNELS, (ch: Channel) => {
        Row() {
          Text(ch.label)
            .fontSize(14.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Text('›')
            .fontSize(15)
            .fontColor('#A8A8A8')
            .margin({ left: 2 })
        }
        .layoutWeight(1)
        .height(46)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.enter(ch.type);
        })
      }, (ch: Channel) => ch.type)
    }
    .width('100%')
    .height(46)
    .backgroundColor('#FFFFFF')
  }

  /** 3. 四个功能圆图标 + 分页点 */
  @Builder
  toolRow() {
    Column() {
      Row() {
        this.toolItem('优惠全知道', 1)
        this.toolItem('爆红包', 2)
        this.toolItem('肯家到店', 3)
        this.toolItem('多人团餐', 4)
      }
      .width('100%')

      Row() {
        Text('')
          .width(13)
          .height(5)
          .borderRadius(3)
          .backgroundColor('#E4002B')
        Text('')
          .width(5)
          .height(5)
          .borderRadius(3)
          .backgroundColor('#E0E0E0')
          .margin({ left: 4 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 9 })
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 2, bottom: 9 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  toolItem(label: string, kind: number) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(46)
          .height(46)
          .fill('#FFFFFF')
          .shadow({ radius: 9, color: '#1A000000', offsetX: 0, offsetY: 2 })

        if (kind === 1) {
          // 日历 + 省
          Text('')
            .width(21)
            .height(19)
            .borderRadius(4)
            .border({ width: 1.4, color: '#E4002B' })
          Text('')
            .width(21)
            .height(4)
            .borderRadius({ topLeft: 3, topRight: 3 })
            .backgroundColor('#E4002B')
            .offset({ x: 0, y: -7.5 })
          Text('省')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E4002B')
            .offset({ x: 0, y: 2.5 })
        } else if (kind === 2) {
          // 红包
          Text('')
            .width(15)
            .height(17)
            .borderRadius(3)
            .backgroundColor('#E4002B')
          Circle()
            .width(4.6)
            .height(4.6)
            .fill('#FFD05B')
            .offset({ x: 0, y: -3 })
          Column() {
            Text('').width(7).height(1.2).backgroundColor('#FFFFFF')
            Text('').width(5).height(1.2).backgroundColor('#FFFFFF').margin({ top: 2 })
          }
          .offset({ x: 0, y: 4 })
        } else if (kind === 3) {
          VectorIcon({ path: Icons.STORE, iconSize: 22, color: '#E4002B' })
        } else {
          // 团餐：红圆 + K
          Circle()
            .width(22)
            .height(22)
            .fill('#E4002B')
          Text('K')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
      }
      .width(46)
      .height(46)

      Text(label)
        .fontSize(10.5)
        .fontColor('#2B2B2B')
        .margin({ top: 8 })
        .maxLines(1)
    }
    .layoutWeight(1)
    .onClick(() => {
      this.notify('「' + label + '」功能正在开发中');
    })
  }

  /** 4. 会员卡 */
  @Builder
  memberCard() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Circle().width(42).height(42).fill('#FFF4F6')

        // 上校卡通头像：白色头发 + 肤色脸 + 眼睛 + 白胡子 + 红领结
        Column() {
          Text('')
            .width(26)
            .height(9)
            .borderRadius({ topLeft: 13, topRight: 13 })
            .backgroundColor('#EFEFEF')
          Column() {
            Row() {
              Circle().width(2.6).height(2.6).fill('#3A3A3A')
              Circle().width(2.6).height(2.6).fill('#3A3A3A').margin({ left: 5 })
            }
            .margin({ top: 4 })

            Text('')
              .width(13)
              .height(3.6)
              .borderRadius(2)
              .backgroundColor('#FFFFFF')
              .margin({ top: 2.5 })

            Row() {
              Text('').width(4).height(3).borderRadius(1).backgroundColor('#E4002B')
              Text('').width(4).height(3).borderRadius(1).backgroundColor('#E4002B').margin({ left: 2 })
            }
            .margin({ top: 1 })
          }
          .width(20)
          .height(15)
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#F6D3B4')
          .borderRadius({ bottomLeft: 7, bottomRight: 7 })
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width(42)
      .height(42)

      Column() {
        Row() {
          Text('元气满满的热美式')
            .fontSize(14.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('大神卡')
            .fontSize(9.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD05B')
            .backgroundColor('#383838')
            .borderRadius(8)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .margin({ left: 5 })
          Text('开通 ›')
            .fontSize(10.5)
            .fontColor('#AFAFAF')
            .margin({ left: 5 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Text('V金')
            .fontSize(11)
            .fontColor('#F0A200')
          Text(this.vgoldText())
            .fontSize(10.5)
            .fontColor('#9A9A9A')
            .margin({ left: 2 })
          Text('卡券')
            .fontSize(10.5)
            .fontColor('#9A9A9A')
            .margin({ left: 13 })
          Text(this.couponText())
            .fontSize(11.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Text('张')
            .fontSize(10.5)
            .fontColor('#9A9A9A')
          Text('余额')
            .fontSize(10.5)
            .fontColor('#9A9A9A')
            .margin({ left: 13 })
          Text(this.balanceText())
            .fontSize(11.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Text('元')
            .fontSize(10.5)
            .fontColor('#9A9A9A')
        }
        .width('100%')
        .margin({ top: 6 })
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .margin({ left: 9 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .borderRadius(11)
    .shadow({ radius: 8, color: '#0C000000', offsetX: 0, offsetY: 2 })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/MemberCardPage' });
    })
  }

  /** 5. 陈列 tab */
  @Builder
  hotTabs() {
    Row() {
      Text('APP热卖')
        .fontSize(15.5)
        .fontWeight(this.hotTab === 'HOT' ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.hotTab === 'HOT' ? '#1A1A1A' : '#8E8E8E')
        .onClick(() => {
          this.hotTab = 'HOT';
          this.cards = this.buildCards('HOT');
        })
      Text('大神卡专区')
        .fontSize(15.5)
        .fontWeight(this.hotTab === 'VIP' ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.hotTab === 'VIP' ? '#1A1A1A' : '#8E8E8E')
        .margin({ left: 22 })
        .onClick(() => {
          this.hotTab = 'VIP';
          this.cards = this.buildCards('VIP');
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 4 })
  }

  /** 6. 两列商品网格 */
  @Builder
  prodGrid() {
    Row() {
      Column() {
        ForEach(this.cards.filter((c: HotCard, i: number) => i % 2 === 0), (c: HotCard) => {
          this.prodCard(c)
        }, (c: HotCard) => c.name + c.price)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column() {
        ForEach(this.cards.filter((c: HotCard, i: number) => i % 2 === 1), (c: HotCard) => {
          this.prodCard(c)
        }, (c: HotCard) => c.name + c.price)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 8 })
    }
    .width('100%')
    .padding({ left: 9, right: 9, top: 5 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  prodCard(card: HotCard) {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          if (card.image.length > 0) {
            Image(this.imgUrl(card.image))
              .width('100%')
              .height(80)
              .objectFit(ImageFit.Contain)
          } else {
            VectorIcon({ path: Icons.BURGER, iconSize: 34, color: '#E0B57A' })
          }
        }
        .width('100%')
        .height(80)
        .justifyContent(FlexAlign.Center)

        if (card.badge.length > 0) {
          Text(card.badge)
            .fontSize(9.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#E4002B')
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .borderRadius({ topLeft: 9, bottomRight: 9 })
        }
      }
      .width('100%')

      Text(card.name)
        .fontSize(11.5)
        .fontColor('#1A1A1A')
        .lineHeight(15)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .height(30)
        .width('100%')
        .margin({ top: 3 })

      Row() {
        Text('¥')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E4002B')
        Text(card.price)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E4002B')
        if (card.from) {
          Text('起')
            .fontSize(9.5)
            .fontColor('#E4002B')
            .margin({ left: 1 })
        }
        Blank()
        Text('¥' + card.origin)
          .fontSize(10.5)
          .fontColor('#B8B8B8')
          .decoration({ type: TextDecorationType.LineThrough, color: '#B8B8B8' })
      }
      .width('100%')
      .margin({ top: 5 })
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 8, bottom: 9 })
    .backgroundColor('#FFFFFF')
    .borderRadius(9)
    .margin({ bottom: 8 })
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.enter('DELIVERY');
    })
  }

  /** 7. 两张券 */
  @Builder
  couponRow() {
    Row() {
      Row() {
        VectorIcon({ path: Icons.DELIVERY, iconSize: 32, color: '#E4002B' })
        Column() {
          Text('免外送费券')
            .fontSize(10.5)
            .fontColor('#4A4A4A')
            .maxLines(1)
          Row() {
            Text('0')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#E4002B')
            Text('元')
              .fontSize(9.5)
              .fontWeight(FontWeight.Bold)
              .fontColor('#E4002B')
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .margin({ left: 6 })
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column() {
          Text('立即')
            .fontSize(9)
            .fontColor('#E4002B')
          Text('使用')
            .fontSize(9)
            .fontColor('#E4002B')
        }
        .padding({ left: 5 })
        .border({ width: { left: 1 }, color: '#33E4002B', style: BorderStyle.Dashed })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .padding({ left: 8, right: 8, top: 11, bottom: 11 })
      .borderRadius(9)
      .linearGradient({
        angle: 120,
        colors: [['#FFF0F3', 0.0], ['#FFE6EC', 1.0]]
      })

      Row() {
        Text('')
          .width(26)
          .height(30)
          .borderRadius(4)
          .backgroundColor('#E4002B')
        Column() {
          Text('外送爆红包')
            .fontSize(10.5)
            .fontColor('#4A4A4A')
            .maxLines(1)
          Row() {
            Text('最高')
              .fontSize(9.5)
              .fontWeight(FontWeight.Bold)
              .fontColor('#E4002B')
            Text('18')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#E4002B')
            Text('元')
              .fontSize(9.5)
              .fontWeight(FontWeight.Bold)
              .fontColor('#E4002B')
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .margin({ left: 6 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .margin({ left: 8 })
      .padding({ left: 8, right: 8, top: 11, bottom: 11 })
      .borderRadius(9)
      .linearGradient({
        angle: 120,
        colors: [['#FFF7E9', 0.0], ['#FFEED6', 1.0]]
      })
    }
    .width('100%')
    .padding({ left: 9, right: 9, top: 9, bottom: 14 })
  }

  // 8. 深色底部 tab 已抽到 components/EntryTabBar.ets（入口页 / 会员中心 / 大神卡三页共用）

  /* ------------------------------ 组装 ------------------------------ */

  build() {
    Column() {
      this.channelBar()

      Scroll() {
        Column() {
          this.hero()
          this.channelRow()
          this.toolRow()

          // 会员卡（灰底上留 9 的白边）
          Column() {
            this.memberCard()
          }
          .width('100%')
          .padding({ left: 9, right: 9, top: 9 })

          this.hotTabs()
          this.prodGrid()
          this.couponRow()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      EntryTabBar({ active: 'home' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F2')
  }
}
