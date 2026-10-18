import { Constants, StoreInfo, Theme } from '../common/Constants';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 首页（选餐厅落地页）—— 复刻肯德基手机端 order.kfc.com.cn/preorder-taro/home
 *
 * 版式数值来自官方运行期 CSS 的实测布局树（390 视口）：
 *   红色条纹 banner 260 高 → 白色大卡（用户条 62 + 门店块 134）上移 36 压住 banner
 *   → 开始点餐（红 56 高 / 圆角 8.3 / 阴影）→ 查看临时订单（白 50 高）
 *
 * 三个取餐通道共用同一个点餐页，只把 pickupType 写进 AppStorage。
 * 官方手机端首页没有底部 tab，这里也不放。
 */
@Entry
@Component
struct EntryPage {

  @StorageLink('pickupType') pickupType: string = 'PICKUP';
  @StorageLink('userId') userId: number = 0;
  @StorageLink('cartCount') cartCount: number = 0;
  @StorageLink('cartAmount') cartAmount: number = 0;
  @StorageLink('userName') userName: string = '';
  @State tempClosed: boolean = false;

  private base: string = Constants.BASE_URL;

  aboutToAppear(): void {
    const id = AppStorage.get<number>('userId');
    if (id !== undefined && id > 0) {
      this.userId = id;
    }
  }

  private notify(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 });
    } catch (e) {
      // 提示失败不影响主流程
    }
  }

  private go(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (e) {
      this.notify('页面跳转失败');
    }
  }

  private goMenu(): void {
    this.go('pages/Index');
  }

  @Builder
  tagChip(txt: string) {
    Text(txt)
      .fontSize(11.4)
      .fontColor('#666660')
      .backgroundColor(Theme.BG)
      .borderRadius(4.2)
      .padding({ left: 5, right: 5, top: 3, bottom: 3 })
      .margin({ right: 6, top: 3 })
  }

  @Builder
  bannerArea() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 官方首页横幅取自服务端配置，默认图只是占位条纹；
      // 这里直接用品牌红渐变 + 字标，视觉上更接近线上实况
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          Text('KFC')
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontStyle(FontStyle.Italic)
            .fontColor('#FFFFFF')
          Text('肯德基')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .letterSpacing(6)
            .margin({ top: 6 })
          Text('吮指美味 · 随时随地')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.9)')
            .letterSpacing(2)
            .margin({ top: 10 })
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 24, top: 34 })
      }
      .width('100%')
      .height(260)
      .linearGradient({
        angle: 160,
        colors: [['#F5123C', 0], ['#E40030', 0.46], ['#B00024', 1]]
      })

      Row() {
        Text('隐私政策').fontSize(10.4).fontColor('#FFFFFF')
        VectorIcon({ path: Icons.CHEVRON, iconSize: 8, color: '#FFFFFF' })
      }
      .padding({ left: 10, right: 10 })
      .height(19)
      .borderRadius(9.4)
      .backgroundColor('rgba(0,0,0,0.3)')
      .margin({ top: 51, right: 15 })
      .onClick(() => this.notify('隐私政策（演示占位）'))
    }
    .width('100%')
    .height(260)
  }

  @Builder
  userRow() {
    Row() {
      Image(this.base + '/images/kfc/icon-avatar-default.png')
        .width(35)
        .height(35)
        .borderRadius(17.5)
      Column() {
        Text(this.userId > 0 && this.userName.length > 0 ? this.userName : '欢迎您，请登录')
          .fontSize(14.6)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.userId > 0 ? '肯德基会员 · 点击查看权益' : '成为肯德基会员享更多优惠')
          .fontSize(10.4)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 11.4 })
      .layoutWeight(1)
    }
    .width('100%')
    .height(62)
    .padding({ left: 12.5, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: Theme.RADIUS, topRight: Theme.RADIUS })
    .onClick(() => {
      if (this.userId > 0) {
        this.go('pages/MinePage');
      } else {
        this.go('pages/LoginPage');
      }
    })
  }

  @Builder
  storeBlock() {
    Row() {
      Column() {
        Row() {
          Text(StoreInfo.NAME)
            .fontSize(19.8)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Image(this.base + '/images/kfc/icon-store-arrow.png')
            .width(15)
            .height(15)
            .margin({ left: 5.7 })
        }
        .alignItems(VerticalAlign.Center)

        Text('距您 ' + StoreInfo.DIST + ' · ' + StoreInfo.HOURS + ' · 营业中')
          .fontSize(11.4)
          .fontColor(Theme.TEXT_HINT)
          .margin({ top: 5.2 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(StoreInfo.TAGS, (t: string) => {
            this.tagChip(t)
          }, (t: string) => t)
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image(this.base + '/images/kfc/icon-store-nolocation.png')
        .width(84)
        .height(84)
    }
    .width('100%')
    .padding({ left: 13.5, right: 20.5, top: 16.6, bottom: 16.6 })
    .backgroundColor('#FFFFFF')
    .borderRadius({ bottomLeft: Theme.RADIUS, bottomRight: Theme.RADIUS })
    .onClick(() => this.go('pages/StorePage'))
  }

  @Builder
  startButton() {
    Row() {
      Image(this.base + '/images/kfc/icon-start-spoon.png')
        .width(17)
        .height(20)
      Column() {
        Text('开始点餐').fontSize(16.6).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Text('Order Now').fontSize(11.4).fontColor('#FFFFFF').margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 8.3 })
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.PRIMARY)
    .borderRadius(8.3)
    .shadow({ radius: 12, color: 'rgba(51,51,51,0.20)', offsetY: 6 })
    .margin({ left: 12.5, right: 12.5, top: 12.5 })
    .onClick(() => this.goMenu())
  }

  @Builder
  tempOrderBar() {
    Row() {
      Row() {
        VectorIcon({ path: Icons.CLOSE, iconSize: 9, color: '#999999' })
      }
      .width(24)
      .height(24)
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(209,209,209,0.16)')
      .onClick(() => {
        this.tempClosed = true;
      })

      Image(this.base + '/images/kfc/icon-horn.png')
        .width(29)
        .height(29)
        .margin({ left: 8, right: 12.5 })

      Column() {
        Text('查看临时订单').fontSize(12.5).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
        Text('未登录订单可在此查看').fontSize(12.5).fontColor(Theme.PRIMARY).margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('点击查看')
        .fontSize(12.5)
        .fontColor(Theme.PRIMARY)
        .height(28)
        .padding({ left: 12.5, right: 12.5 })
        .border({ width: 0.5, color: Theme.PRIMARY })
        .borderRadius(4.2)
        .onClick(() => this.notify('未登录订单功能开发中'))
    }
    .width('100%')
    .height(50)
    .padding({ left: 8, right: 13.5 })
    .backgroundColor('#FFFFFF')
    .borderRadius(Theme.RADIUS)
    .margin({ left: 12.5, right: 12.5, top: 12.5, bottom: 16.6 })
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Stack({ alignContent: Alignment.Top }) {
            this.bannerArea()

            Column() {
              Column() {
                this.userRow()
                this.storeBlock()
              }
              .width('100%')
              .backgroundColor('#FFFFFF')
              .borderRadius(Theme.RADIUS)
              .shadow({ radius: 21, color: Theme.SHADOW, offsetY: 2 })
              .margin({ left: 12.5, right: 12.5 })

              this.startButton()

              if (!this.tempClosed) {
                this.tempOrderBar()
              } else {
                Blank().height(16.6)
              }
            }
            .width('100%')
            .margin({ top: 224 })   // 260 - 36.4：卡片压住 banner
          }
          .width('100%')
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
