import { Theme } from '../common/Constants';
import { User } from '../model/User';
import { UserApi } from '../api/UserApi';
import { MemberCard, MemberSummary } from '../model/Member';
import { MemberApi } from '../api/MemberApi';
import { Icons, VectorIcon } from '../components/VectorIcon';
import { EntryTabBar } from '../components/EntryTabBar';

/** 四项会员数据（V金 / 卡券 / 余额 / 成就，取自 /api/member/summary） */
interface WowStat {
  value: string;
  label: string;
}

/**
 * WOW 会员中心
 *
 * 版式照官方小程序「会员中心」页：
 *   灰色男孩剪影头部（Canvas 手绘）+ 右上四个工具图标
 *   → 粉色胶囊「点亮您的会员成就」→ 昵称 + WOW会员标签 + 会员号
 *   → 四格数据（成就 / V金 / 卡券 / 余额）
 *   → 四个功能入口（我的订单 / 送餐地址 / 车辆档案 / 自助服务）
 *   → 层叠会员卡（咖啡卡小条 + 大神卡主体）→ 深色底部 tab
 *
 * 数据来自 t_member（会员号 / V金 / 卡券 / 余额 / 成就）与 t_member_card（生效卡）；
 * 未登录或接口不通时四项显示「--」，不会把 0 当成真实值误导人。
 */
@Entry
@Component
struct WOWMemberPage {

  @StorageLink('userId') userId: number = 0;

  @State user: User | null = null;

  /** 会员概要（会员号 / V金 / 卡券 / 余额 / 成就 / 生效卡） */
  @State summary: MemberSummary | null = null;

  /** 头部剪影画布 */
  private figCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  private async load(): Promise<void> {
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

  private displayName(): string {
    if (this.summary !== null) {
      const nick: string | undefined = this.summary.nickname;
      if (nick !== undefined && nick.length > 0) {
        return nick;
      }
    }
    if (this.user === null) {
      return this.userId > 0 ? '会员' : '未登录';
    }
    const userName: string | undefined = this.user.nickname;
    if (userName !== undefined && userName.length > 0) {
      return userName;
    }
    return this.user.username;
  }

  /** 会员号：NO. 8000 0113，四位一空格 */
  private memberNo(): string {
    if (this.summary === null) {
      return this.userId > 0 ? '会员号同步中…' : '登录后同步会员号';
    }
    const raw: string = this.summary.memberNo;
    let out: string = '';
    for (let i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 === 0) {
        out += ' ';
      }
      out += raw.charAt(i);
    }
    return 'NO. ' + out;
  }

  /** 大数字口吻保持一致：V金满 1 万按「万」显示 */
  private vgoldText(value: number): string {
    if (value >= 10000) {
      return (value / 10000).toFixed(1) + '万';
    }
    return value.toString();
  }

  /** 四格数据：未登录 / 接口失败一律「--」，不拿 0 冒充真实值 */
  private statList(): WowStat[] {
    const s: MemberSummary | null = this.summary;
    if (s === null) {
      return [
        { value: '--', label: '成就' },
        { value: '--', label: 'V金' },
        { value: '--', label: '卡券' },
        { value: '--', label: '余额' }
      ];
    }
    return [
      { value: s.achievement > 0 ? s.achievement.toString() : '--', label: '成就' },
      { value: this.vgoldText(s.vgold), label: 'V金' },
      { value: s.couponCount.toString(), label: '卡券' },
      { value: Number(s.balance).toFixed(0), label: '余额' }
    ];
  }

  /** 生效中的卡：type 传 GOD / COFFEE */
  private activeCard(type: string): MemberCard | null {
    if (this.summary === null) {
      return null;
    }
    for (let i = 0; i < this.summary.cards.length; i++) {
      if (this.summary.cards[i].cardType === type) {
        return this.summary.cards[i];
      }
    }
    return null;
  }

  /** 卡标题：有卡用真实档位名，没卡用默认档位占位 */
  private cardLabel(type: string, fallback: string): string {
    const card: MemberCard | null = this.activeCard(type);
    if (card === null) {
      return fallback;
    }
    return (type === 'GOD' ? '大神卡 · ' : '咖啡卡 · ') + card.cardName;
  }

  /** 卡状态：生效中显示剩余天数，否则未开通 */
  private cardStatus(type: string): string {
    const card: MemberCard | null = this.activeCard(type);
    if (card === null) {
      return '未开通';
    }
    return '剩余 ' + card.remainDays + ' 天';
  }

  private tip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      console.warn('showToast failed: ' + JSON.stringify(e));
    }
  }

  /* ---------------------- 头部剪影（Canvas） ---------------------- */

  private drawFigure(): void {
    const c = this.figCtx;
    const w = c.width;
    const h = c.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const s = Math.min(w / 210, h / 224);
    const ox = (w - 210 * s) / 2;
    const oy = h - 224 * s;
    const X = (v: number): number => ox + v * s;
    const Y = (v: number): number => oy + v * s;
    c.clearRect(0, 0, w, h);

    // 脖子（先画，接住头与肩，否则中间会断一截）
    c.fillStyle = '#DCDCDC';
    c.fillRect(X(107), Y(80), 30 * s, 30 * s);

    // 头
    c.beginPath();
    c.arc(X(122), Y(58), 33 * s, 0, Math.PI * 2);
    c.closePath();
    c.fillStyle = '#DCDCDC';
    c.fill();

    // 身体
    c.beginPath();
    c.moveTo(X(122), Y(100));
    c.bezierCurveTo(X(88), Y(100), X(64), Y(121), X(58), Y(151));
    c.lineTo(X(53), Y(224));
    c.lineTo(X(191), Y(224));
    c.lineTo(X(186), Y(151));
    c.bezierCurveTo(X(180), Y(121), X(156), Y(100), X(122), Y(100));
    c.closePath();
    c.fillStyle = '#DCDCDC';
    c.fill();

    // 头发（比头略深的半圆帽）
    c.beginPath();
    c.arc(X(122), Y(58), 33 * s, Math.PI * 1.04, Math.PI * 1.96);
    c.closePath();
    c.fillStyle = '#C9C9C9';
    c.fill();

    // 左侧肩部阴影
    c.beginPath();
    c.moveTo(X(58), Y(151));
    c.bezierCurveTo(X(64), Y(121), X(88), Y(100), X(122), Y(100));
    c.lineTo(X(122), Y(112));
    c.bezierCurveTo(X(92), Y(114), X(72), Y(134), X(66), Y(160));
    c.lineTo(X(60), Y(186));
    c.closePath();
    c.fillStyle = '#C9C9C9';
    c.fill();
  }

  /* ---------------------------- 分块 UI ---------------------------- */

  /** 1. 头部：剪影 + 工具图标 + 粉色胶囊 + 昵称 + 会员号 */
  @Builder
  head() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Text('')
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 170,
          colors: [['#EBEBEB', 0.0], ['#F4F4F4', 1.0]]
        })

      Canvas(this.figCtx)
        .width(206)
        .height(220)
        .onReady(() => {
          this.drawFigure();
        })

      Column() {
        // 右上工具：消息 / 会员码 / 扫一扫 / 设置
        Row() {
          this.headTool(Icons.BELL, true)
          this.headTool(Icons.QR, false)
          this.headTool(Icons.SCAN, false)
          this.headTool(Icons.GEAR, false)
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .padding({ right: 8 })
        .margin({ top: 12 })

        Row() {
          Text('点亮您的会员成就')
            .fontSize(12.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#C8304E')
          Text('›')
            .fontSize(14)
            .fontColor('#C8304E')
            .margin({ left: 5 })
        }
        .height(34)
        .padding({ left: 14, right: 12 })
        .borderRadius(17)
        .backgroundColor('#FFE6EC')
        .margin({ left: 18, top: 34 })
        .onClick(() => {
          this.tip('「会员成就」功能正在开发中');
        })

        Blank()

        Row() {
          Text(this.displayName())
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Text('WOW会员')
            .fontSize(9.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF7A8C')
            .backgroundColor('#1F1F1F')
            .borderRadius(3)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center)

        Text(this.memberNo())
          .fontSize(10.5)
          .fontColor('#A0A0A0')
          .width('100%')
          .padding({ left: 18 })
          .margin({ top: 6, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(250)
    .clip(true)
  }

  @Builder
  headTool(path: string, dot: boolean) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        VectorIcon({ path: path, iconSize: 21, color: '#4E4E4E' })
      }
      .width(30)
      .height(30)
      .justifyContent(FlexAlign.Center)

      if (dot) {
        Circle()
          .width(6)
          .height(6)
          .fill(Theme.PRIMARY)
          .margin({ top: 4, right: 6 })
      }
    }
    .width(30)
    .height(30)
    .margin({ left: 2 })
    .onClick(() => {
      this.tip('功能正在开发中');
    })
  }

  /** 2. 四格数据 */
  @Builder
  statsRow() {
    Column() {
      Row() {
        ForEach(this.statList(), (s: WowStat, i: number) => {
          if (i > 0) {
            Divider()
              .vertical(true)
              .height(28)
              .width(1)
              .color('#F1F1F1')
          }
          Column() {
            Text(s.value)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Text(s.label)
              .fontSize(10.5)
              .fontColor('#9A9A9A')
              .margin({ top: 4 })
          }
          .layoutWeight(1)
        }, (s: WowStat) => s.label)
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
      .borderRadius(12)
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
  }

  /** 3. 四个功能入口 */
  @Builder
  actsRow() {
    Column() {
      Row() {
        this.actItem(Icons.RECEIPT, '我的订单', () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/OrderListPage' });
        })
        this.actItem(Icons.LOCATION, '送餐地址', () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/AddressPage' });
        })
        this.actItem(Icons.CAR, '车辆档案', () => {
          this.tip('「车辆档案」功能正在开发中');
        })
        this.actItem(Icons.HELP, '自助服务', () => {
          this.tip('「自助服务」功能正在开发中');
        })
      }
      .width('100%')
      .padding({ top: 16, bottom: 14 })
      .borderRadius(12)
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10 })
  }

  @Builder
  actItem(path: string, label: string, action: () => void) {
    Column() {
      VectorIcon({ path: path, iconSize: 21, color: Theme.PRIMARY })
      Text(label)
        .fontSize(11)
        .fontColor('#4A4A4A')
        .margin({ top: 7 })
        .maxLines(1)
    }
    .layoutWeight(1)
    .onClick(action)
  }

  /** 4. 层叠会员卡（咖啡卡小条在上，大神卡主体压下来 18vp） */
  @Builder
  cardsBlock() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        // 底层小条：咖啡卡
        Row() {
          Text(this.cardLabel('COFFEE', '咖啡卡 · 30天'))
            .fontSize(12.5)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B23A50')
          Text(this.cardStatus('COFFEE'))
            .fontSize(11)
            .fontColor('#C89AA4')
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .justifyContent(FlexAlign.SpaceBetween)
        .borderRadius(12)
        .backgroundColor('#FFF1F4')
        .border({ width: 1, color: '#FFDCE3' })

        // 主卡：大神卡（margin 38 = 小条 56 - 压叠 18）
        Column() {
          Row() {
            Column() {
              Text(this.cardLabel('GOD', '大神卡 · 季卡'))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(this.cardStatus('GOD'))
                .fontSize(10.5)
                .fontColor('#C7FFFFFF')
                .margin({ top: 5 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.activeCard('GOD') === null ? '立即开通' : '立即续费')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#D4001F')
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .padding({ left: 11, right: 11, top: 5, bottom: 5 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Row() {
            this.benefit('免', '满额免外送费')
            this.benefit('2', '饮料 2 杯')
            this.benefit('6折', '早餐 6 折起')
          }
          .width('100%')
          .padding({ top: 13 })
          .margin({ top: 14 })
          .border({ width: { top: 1 }, color: '#38FFFFFF' })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 15, bottom: 16 })
        .margin({ top: 38 })
        .borderRadius(12)
        .linearGradient({
          angle: 135,
          colors: [['#EF0038', 0.0], ['#C50023', 0.62], ['#A8001D', 1.0]]
        })
        .shadow({ radius: 18, color: '#38E4002B', offsetX: 0, offsetY: 8 })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/MemberCardPage' });
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .margin({ top: 16 })
  }

  @Builder
  benefit(big: string, small: string) {
    Column() {
      Text(big)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD05B')
      Text(small)
        .fontSize(9.5)
        .fontColor('#DBFFFFFF')
        .margin({ top: 4 })
        .maxLines(1)
    }
    .layoutWeight(1)
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          this.head()
          this.statsRow()
          this.actsRow()
          this.cardsBlock()
          Text('')
            .width('100%')
            .height(16)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      EntryTabBar({ active: 'wow' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F4F4')
  }
}
