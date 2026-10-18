import { Theme } from '../common/Constants';
import { User } from '../model/User';
import { UserApi } from '../api/UserApi';
import { Icons, VectorIcon } from '../components/VectorIcon';
import { EntryTabBar } from '../components/EntryTabBar';

/** 大神卡套餐档位 */
interface CardPlan {
  name: string;
  price: string;
  origin: string;
  days: string;
}

/** 特权行 */
interface Privilege {
  icon: string;
  title: string;
  desc: string;
}

const CARD_PLANS: CardPlan[] = [
  { name: '季卡', price: '30', origin: '38', days: '90 天' },
  { name: '年卡', price: '100', origin: '108', days: '365 天' },
  { name: '月卡', price: '19', origin: '25', days: '30 天' }
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

  /** 当前档位 tab */
  @State cardTab: string = '大神卡';

  /** 当前选中的套餐下标 */
  @State planIdx: number = 0;

  /** 主视觉红皇冠画布 */
  private crownCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    if (this.userId <= 0) {
      this.user = null;
      return;
    }
    try {
      this.user = await UserApi.detail(this.userId);
    } catch (err) {
      this.user = null;
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

  private plan(): CardPlan {
    return CARD_PLANS[this.planIdx];
  }

  private afterCoupon(): string {
    return (Number(this.plan().price) - 5).toString();
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
        Text(this.isGod() ? '开通大神卡 立享 11 项特权' : '开通咖啡卡 天天 9.9 元')
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
      this.cardTab = label;
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
      ForEach(CARD_PLANS, (p: CardPlan, i: number) => {
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
            Text(p.price)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.planIdx === i ? Theme.PRIMARY : '#1A1A1A')
          }
          .alignItems(VerticalAlign.Bottom)
          .margin({ top: 5 })

          Text('¥' + p.origin)
            .fontSize(10)
            .fontColor('#B5B5B5')
            .decoration({ type: TextDecorationType.LineThrough, color: '#B5B5B5' })
            .margin({ top: 4 })
          Text(p.days)
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
      }, (p: CardPlan) => p.name)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  /** 6. 特权标题 */
  @Builder
  privHead() {
    Row() {
      Text((this.isGod() ? '11' : '8') + ' 特权')
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
          Text(this.plan().price)
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

      Text('立即购买')
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
          this.tip('「立即购买」功能正在开发中');
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
