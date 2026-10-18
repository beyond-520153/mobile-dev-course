import { Theme } from '../common/Constants';
import { Icons, VectorIcon } from '../components/VectorIcon';
import { User } from '../model/User';
import { UserApi } from '../api/UserApi';
import { CartViewModel } from '../viewmodel/CartViewModel';

/**
 * 我的 —— 对齐官方会员中心的红色头 + 三格权益 + 白色入口卡。
 * 未登录时头部直接给「立即登录」，登录后显示昵称与 V金。
 */
@Entry
@Component
struct MinePage {

  @StorageLink('userId') userId: number = 0;
  @StorageLink('userName') userName: string = '';
  @StorageLink('cartCount') cartCount: number = 0;
  @State user: User | null = null;

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  private async load(): Promise<void> {
    if (this.userId <= 0) {
      this.user = null;
      return;
    }
    try {
      this.user = await UserApi.detail(this.userId);
      if (this.user.nickname !== undefined && this.user.nickname.length > 0) {
        this.userName = this.user.nickname;
      }
    } catch (e) {
      // 离线时保留本地显示
    }
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      // 忽略
    }
  }

  private go(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (e) {
      this.toast('页面跳转失败');
    }
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (e) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/EntryPage' });
      } catch (e2) {
        this.toast('返回失败');
      }
    }
  }

  private async logout(): Promise<void> {
    CartViewModel.clearUser();
    this.user = null;
    this.toast('已退出登录');
    this.back();
  }

  @Builder
  stat(label: string, value: string) {
    Column() {
      Text(label).fontSize(10.4).fontColor('rgba(255,255,255,0.82)')
      Text(value)
        .fontSize(16.6)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 3 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 9, bottom: 9 })
    .backgroundColor('rgba(255,255,255,0.16)')
    .borderRadius(8)
    .margin({ right: 8 })
  }

  @Builder
  head() {
    Column() {
      Row() {
        Row() {
          VectorIcon({ path: Icons.ARROW_BACK, iconSize: 20, color: '#FFFFFF' })
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.back())
      }
      .width('100%')

      Row() {
        Row() {
          VectorIcon({ path: Icons.PERSON, iconSize: 28, color: '#FFFFFF' })
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255,255,255,0.24)')

        Column() {
          Text(this.userId > 0 ? (this.userName.length > 0 ? this.userName : '肯德基会员') : '欢迎您，请登录')
            .fontSize(17.7)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(this.userId > 0 ? '肯德基会员 · V金 0' : '成为肯德基会员享更多优惠')
            .fontSize(11.4)
            .fontColor('rgba(255,255,255,0.82)')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        if (this.userId <= 0) {
          Text('立即登录')
            .fontSize(12.5)
            .fontColor('#FFFFFF')
            .height(27)
            .padding({ left: 14, right: 14 })
            .border({ width: 0.5, color: '#FFFFFF' })
            .borderRadius(14)
            .onClick(() => this.go('pages/LoginPage'))
        }
      }
      .width('100%')
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Center)

      Row() {
        this.stat('优惠券', '0')
        this.stat('V金', '0')
        this.stat('大神卡', '未开通')
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 22 })
    .backgroundColor(Theme.PRIMARY)
  }

  @Builder
  row(icon: string, label: string, value: string, action: () => void) {
    Row() {
      Row() {
        VectorIcon({ path: icon, iconSize: 17, color: Theme.TEXT_SUB })
      }
      .width(26)

      Text(label).fontSize(13.5).fontColor(Theme.TEXT).layoutWeight(1)

      Text(value).fontSize(11.4).fontColor(Theme.TEXT_HINT).margin({ right: 4 })
      VectorIcon({ path: Icons.CHEVRON, iconSize: 14, color: '#C9C9C9' })
    }
    .width('100%')
    .height(50)
    .padding({ left: 13, right: 13 })
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          this.head()

          Column() {
            this.row(Icons.ORDER, '我的订单', '', () => this.go('pages/OrderListPage'))
            Divider().color('#F5F5F5').margin({ left: 39 })
            this.row(Icons.LOCATION, '收货地址', '', () => this.go('pages/AddressPage'))
            Divider().color('#F5F5F5').margin({ left: 39 })
            this.row(Icons.COUPON, '优惠券', '', () => this.toast('优惠券功能开发中'))
            Divider().color('#F5F5F5').margin({ left: 39 })
            this.row(Icons.GIFT, 'V金商城', '', () => this.toast('V金商城功能开发中'))
            if (this.userId > 0) {
              Divider().color('#F5F5F5').margin({ left: 39 })
              this.row(Icons.LOGOUT, '退出登录', '', () => this.logout())
            }
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(Theme.RADIUS)
          .margin({ left: 12.5, right: 12.5, top: 10 })
          .clip(true)

          Text('KFC 点餐 · 课程设计演示')
            .fontSize(10.4)
            .fontColor('#C9C9C9')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 14, bottom: 24 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
