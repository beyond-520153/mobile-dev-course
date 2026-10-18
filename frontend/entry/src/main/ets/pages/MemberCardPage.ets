import { Theme } from '../common/Constants';
import { User } from '../model/User';
import { UserApi } from '../api/UserApi';
import { MemberCard, MemberPlan, MemberSummary } from '../model/Member';
import { MemberApi } from '../api/MemberApi';
import { Icons, VectorIcon } from '../components/VectorIcon';
import { EntryTabBar } from '../components/EntryTabBar';

/** 特权行 */
interface Privilege {
  icon: string;
  title: string;
  desc: string;
}

/**
 * 接口拿不到时的兜底档位（与 V4__member.sql 的种子数据一致）
 *
 * 只在后端没起 / 请求失败时用，正常路径一定走 /api/member/plans。
 */
const FALLBACK_PLANS: MemberPlan[] = [
  { id: 1, code: 'GOD_SEASON', cardType: 'GOD', name: '季卡', months: 3,
    price: 30, originPrice: 38, privilegeNum: 11, days: 90 },
  { id: 2, code: 'GOD_YEAR', cardType: 'GOD', name: '年卡', months: 12,
    price: 100, originPrice: 108, privilegeNum: 11, days: 365 },
  { id: 3, code: 'GOD_MONTH', cardType: 'GOD', name: '月卡', months: 1,
    price: 19, originPrice: 25, privilegeNum: 11, days: 30 },
  { id: 4, code: 'COFFEE_30', cardType: 'COFFEE', name: '咖啡卡 · 30天', months: 1,
    price: 12, originPrice: 15, privilegeNum: 8, days: 30 }
];

const GOD_PRIVS: Privilege[] = [
  { icon: Icons.DELIVERY, title: '满额免外送费', desc: '单笔满 39 元免配送费' },
  { icon: Icons.BURGER, title: '饮料 2 杯', desc: '每月赠 2 杯中杯饮料' },
  { icon: Icons.PLATE, title: '早餐 6 折起', desc: '工作日 10:30 前可用' }
];

const COFFEE_PRIVS: Privilege[] = [
  { icon: Icons.DELIVERY, title: '免外送费', desc: '单笔满 29 元免配送费' },
  { icon: Icons.BURGER, title: '天天 9.9 元', desc: '指定咖啡天天 9.9 元' },
  { icon: Icons.PLATE, title: '早餐 7 折起', desc: '工作日 10:30 前可用' }
];

/**
 * 大神卡（付费会员）
 *
 * 版式照官方「付费会员」页：
 *   白导航（付费会员 / 杭州市）→ 用户条 → 大神卡·咖啡卡双 tab
 *   → 黑金主视觉（红皇冠 + 竖排「大神卡。」+ 2026，Canvas 手绘）
 *   → 三档价格卡（可点选联动底部价格）→ 特权列表 → 底部固定购买条
 *
 * 「大神卡」与「咖啡卡」共用同一套版式，只换主视觉文案与特权条数（11 / 8）。
 * 购买链路后端还没有支付，先给开发中提示。
 */
@Entry
@Component
struct MemberCardPage {

  @StorageLink('userId') userId: number = 0;

  @State user: User | null = null;

  /** 会员概要（判断是否已持卡 / 剩余天数） */
  @State summary: MemberSummary | null = null;

  /** 当前 tab 的在售档位（接口优先，失败时回落到 FALLBACK_PLANS） */
  @State planData: MemberPlan[] = [];

  /** 当前档位 tab */
  @State cardTab: string = '大神卡';

  /** 当前选中的套餐下标 */
  @State planIdx: number = 0;

  /** 开通请求进行中，防连点 */
  @State buying: boolean = false;

  /** 主视觉红皇冠画布 */
  private crownCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    await this.loadPlans();
    if (this.userId <= 0) {
      this.user = null;
      this.summary = null;
      return;
    }
    try {
      this.summary = await MemberApi.summary(this.userId);
    } catch (err) {
      this.summary = null;
    }
    try {
      this.user = await UserApi.detail(this.userId);
    } catch (err) {
      this.user = null;
    }
  }

  /** 拉当前 tab 的在售档位；失败就留空，界面会走兜底数据 */
  private async loadPlans(): Promise<void> {
    try {
      this.planData = await MemberApi.plans(this.isGod() ? 'GOD' : 'COFFEE');
    } catch (err) {
      this.planData = [];
    }
  }

  private isGod(): boolean {
    return this.cardTab === '大神卡';
  }

  private displayName(): string {
    if (this.user === null) {
      return '未登录';
    }
    const nick: string | undefined = this.user.nickname;
    return nick !== undefined && nick.length > 0 ? nick : this.user.username;
  }

  /** 当前 tab 的档位列表；接口没返回就用兜底，页面不会空着 */
  private planList(): MemberPlan[] {
    if (this.planData.length > 0) {
      return this.planData;
    }
    const type: string = this.isGod() ? 'GOD' : 'COFFEE';
    const out: MemberPlan[] = [];
    for (let i = 0; i < FALLBACK_PLANS.length; i++) {
      if (FALLBACK_PLANS[i].cardType === type) {
        out.push(FALLBACK_PLANS[i]);
      }
    }
    return out;
  }

  private plan(): MemberPlan {
    const list: MemberPlan[] = this.planList();
    if (list.length === 0) {
      return FALLBACK_PLANS[0];
    }
    const idx: number = this.planIdx < list.length ? this.planIdx : 0;
    return list[idx];
  }

  /** 用户条副标题：已持卡报剩余天数，未持卡报卖点 */
  private subTitle(): string {
    const card: MemberCard | null = this.holdingCard();
    if (card !== null) {
      return (this.isGod() ? '大神卡' : '咖啡卡') + '生效中 · 剩余 ' + card.remainDays + ' 天';
    }
    return this.isGod() ? '开通大神卡 立享 ' + this.privCount() + ' 项特权' : '开通咖啡卡 天天 9.9 元';
  }

  /** 价格去掉多余的 .00，非整数保留两位 */
  private priceText(value: number): string {
    return Number.isInteger(value) ? value.toFixed(0) : value.toFixed(2);
  }

  private afterCoupon(): string {
    return this.priceText(Number(this.plan().price) - 5);
  }

  /** 当前 tab 的特权条数（取该 tab 第一个档位的配置） */
  private privCount(): number {
    const list: MemberPlan[] = this.planList();
    if (list.length > 0) {
      return list[0].privilegeNum;
    }
    return this.isGod() ? 11 : 8;
  }

  /** 当前 tab 已持有的卡 */
  private holdingCard(): MemberCard | null {
    if (this.summary === null) {
      return null;
    }
    const type: string = this.isGod() ? 'GOD' : 'COFFEE';
    for (let i = 0; i < this.summary.cards.length; i++) {
      if (this.summary.cards[i].cardType === type) {
        return this.summary.cards[i];
      }
    }
    return null;
  }

  /** 开通 / 续费：未登录先登录，成功后就地刷新概要 */
  private async buy(): Promise<void> {
    if (this.buying) {
      return;
    }
    if (this.userId <= 0) {
      this.tip('请先登录再开通');
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    const wasHolding: boolean = this.holdingCard() !== null;
    this.buying = true;
    try {
      this.summary = await MemberApi.open(this.userId, this.plan().code);
      const name: string = this.isGod() ? '大神卡' : '咖啡卡';
      this.tip(wasHolding ? name + '续费成功' : name + '开通成功');
    } catch (err) {
      this.tip(`${err}`.replace('Error: ', ''));
    } finally {
      this.buying = false;
    }
  }

  private privs(): Privilege[] {
    return this.isGod() ? GOD_PRIVS : COFFEE_PRIVS;
  }

  private tip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      console.warn('showToast failed: ' + JSON.stringify(e));
    }
  }

  /* ---------------------- 主视觉皇冠（Canvas） ---------------------- */

  private drawCrown(): void {
    const c = this.crownCtx;
    const w = c.width;
    const h = c.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const s = Math.min(w / 132, h / 96);
    c.clearRect(0, 0, w, h);

    // 三尖皇冠
    c.beginPath();
    c.moveTo(10 * s, 78 * s);
    c.lineTo(122 * s, 78 * s);
    c.lineTo(112 * s, 26 * s);
    c.lineTo(86 * s, 46 * s);
    c.lineTo(66 * s, 12 * s);
    c.lineTo(46 * s, 46 * s);
    c.lineTo(20 * s, 26 * s);
    c.closePath();
    c.fillStyle = '#E4002B';
    c.fill();

    // 底座
    c.fillRect(10 * s, 82 * s, 112 * s, 9 * s);

    // 宝石
    c.globalAlpha = 0.55;
    c.beginPath();
    c.arc(66 * s, 60 * s, 7 * s, 0, Math.PI * 2);
    c.closePath();
    c.fillStyle = '#141414';
    c.fill();
    c.globalAlpha = 1;
  }

  /* ---------------------------- 分块 UI ---------------------------- */

  /** 1. 白导航 */
  @Builder
  navBar() {
    Row() {
      Column() {
        VectorIcon({ path: Icons.ARROW_BACK, iconSize: 21, color: '#1A1A1A' })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.getUIContext().getRouter().back();
      })

      Text('付费会员')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text('杭州市 ▾')
        .fontSize(12)
        .fontColor('#666666')
        .width(74)
        .textAlign(TextAlign.End)
        .padding({ right: 12 })
    }
    .width('100%')
    .height(52)
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  /** 2. 用户条 */
  @Builder
  userRow() {
    Row() {
      Column() {
        VectorIcon({ path: Icons.PERSON, iconSize: 22, color: Theme.PRIMARY })
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('#FFEDF0')
      .justifyContent(FlexAlign.Center)

      Column() {
        Text(this.displayName())
          .fontSize(14.5)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Text(this.subTitle())
          .fontSize(11)
          .fontColor('#9A9A9A')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)

      Text(this.userId > 0 ? '已登录' : '去登录')
        .fontSize(11.5)
        .fontColor(Theme.PRIMARY)
        .borderRadius(12)
        .border({ width: 1, color: '#FFD3DA' })
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .onClick(() => {
          if (this.userId <= 0) {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  /** 3. 大神卡 / 咖啡卡双 tab */
  @Builder
  tabs() {
    Row() {
      this.tabItem('大神卡')
      this.tabItem('咖啡卡')
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#F0F0F0' })
  }

  @Builder
  tabItem(label: string) {
    Column() {
      Text(label)
        .fontSize(13.5)
        .fontWeight(this.cardTab === label ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.cardTab === label ? '#1A1A1A' : '#8A8A8A')
      Text('')
        .width(22)
        .height(2.5)
        .borderRadius(2)
        .backgroundColor(this.cardTab === label ? Theme.PRIMARY : Color.Transparent)
        .margin({ top: 7 })
    }
    .layoutWeight(1)
    .padding({ top: 12 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (this.cardTab === label) {
        return;
      }
      this.cardTab = label;
      this.planIdx = 0;
      this.loadPlans();
    })
  }

  /** 4. 黑金主视觉 */
  @Builder
  vision() {
    Stack({ alignContent: Alignment.TopStart }) {
      Text('')
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 150,
          colors: [['#1B1B1B', 0.0], ['#101010', 0.6], ['#000000', 1.0]]
        })

      Canvas(this.crownCtx)
        .width(78)
        .height(57)
        .margin({ left: 22, top: 24 })
        .onReady(() => {
          this.drawCrown();
        })

      // 竖排「大神卡。」—— 红点收尾
      Row() {
        Column() {
          Text(this.isGod() ? '大' : '咖')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(this.isGod() ? '神' : '啡')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .margin({ top: 3 })
          Text('卡')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .margin({ top: 3 })
          Text('。')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Top)
      .padding({ right: 30, top: 20 })

      Row() {
        Text('2026')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontStyle(FontStyle.Italic)
          .fontColor(Theme.PRIMARY)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Bottom)
      .padding({ right: 24, bottom: 12 })
    }
    .width('100%')
    .height(196)
    .borderRadius(12)
    .clip(true)
  }

  /** 5. 三档价格卡 */
  @Builder
  plans() {
    Row() {
      ForEach(this.planList(), (p: MemberPlan, i: number) => {
        Column() {
          Text(p.name)
            .fontSize(12)
            .fontColor('#666666')
          Row() {
            Text('¥')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.planIdx === i ? Theme.PRIMARY : '#1A1A1A')
              .margin({ right: 1 })
            Text(this.priceText(Number(p.price)))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.planIdx === i ? Theme.PRIMARY : '#1A1A1A')
          }
          .alignItems(VerticalAlign.Bottom)
          .margin({ top: 5 })

          Text('¥' + this.priceText(Number(p.originPrice)))
            .fontSize(10)
            .fontColor('#B5B5B5')
            .decoration({ type: TextDecorationType.LineThrough, color: '#B5B5B5' })
            .margin({ top: 4 })
          Text(p.days + ' 天')
            .fontSize(10)
            .fontColor('#9A9A9A')
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .padding({ top: 12, bottom: 10 })
        .borderRadius(10)
        .border({
          width: 1.5,
          color: this.planIdx === i ? Theme.PRIMARY : Color.Transparent
        })
        .backgroundColor(this.planIdx === i ? '#FFF7F8' : '#FFFFFF')
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.planIdx = i;
        })
      }, (p: MemberPlan) => p.code)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  /** 6. 特权标题 */
  @Builder
  privHead() {
    Row() {
      Text(this.privCount() + ' 特权')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Blank()
      Text('规则说明')
        .fontSize(11)
        .fontColor('#9A9A9A')
    }
    .width('100%')
    .padding({ top: 18, bottom: 8 })
  }

  /** 7. 特权列表 */
  @Builder
  privList() {
    Column() {
      ForEach(this.privs(), (p: Privilege, i: number) => {
        Row() {
          Column() {
            VectorIcon({ path: p.icon, iconSize: 19, color: Theme.PRIMARY })
          }
          .width(34)
          .height(34)
          .borderRadius(17)
          .backgroundColor('#FFF1F3')
          .justifyContent(FlexAlign.Center)

          Column() {
            Text(p.title)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Text(p.desc)
              .fontSize(10.5)
              .fontColor('#9A9A9A')
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .margin({ left: 11 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .border({
          width: { bottom: i < this.privs().length - 1 ? 1 : 0 },
          color: '#F5F5F5'
        })
        .alignItems(VerticalAlign.Center)
      }, (p: Privilege) => p.title)
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
  }

  /** 8. 底部固定购买条 */
  @Builder
  buyBar() {
    Row() {
      Column() {
        Row() {
          Text('¥')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
          Text(this.priceText(Number(this.plan().price)))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
        }
        .alignItems(VerticalAlign.Bottom)

        Text('券后价 ¥' + this.afterCoupon())
          .fontSize(10)
          .fontColor('#9A9A9A')
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .width(84)

      Text('赠好友')
        .fontSize(11.5)
        .fontColor('#666666')
        .borderRadius(14)
        .border({ width: 1, color: '#E6E6E6' })
        .padding({ left: 11, right: 11, top: 5, bottom: 5 })
        .onClick(() => {
          this.tip('「赠好友」功能正在开发中');
        })

      Text(this.holdingCard() === null ? '立即购买' : '立即续费')
        .fontSize(14.5)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(42)
        .borderRadius(21)
        .backgroundColor(Theme.PRIMARY)
        .margin({ left: 10 })
        .onClick(() => {
          this.buy();
        })
    }
    .width('100%')
    .height(60)
    .padding({ left: 14, right: 14 })
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#F0F0F0' })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.navBar()

      Scroll() {
        Column() {
          this.userRow()
          this.tabs()

          Column() {
            this.vision()
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12 })

          Column() {
            this.plans()
          }
          .width('100%')
          .padding({ left: 12, right: 12 })

          Column() {
            this.privHead()
            this.privList()
            Text('')
              .width('100%')
              .height(12)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      this.buyBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F4F4')
  }
}
