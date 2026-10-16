import { Theme, Constants } from '../common/Constants';
import { User } from '../model/User';
import { UserApi } from '../api/UserApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { BottomTabBar } from '../components/BottomTabBar';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 我的页
 *
 * 展示当前账号信息 + 常用入口。未登录时顶部直接给登录入口。
 */
@Entry
@Component
struct MinePage {

  @State user: User | null = null;
  @State loading: boolean = true;

  @StorageLink('userId') userId: number = 0;
  @StorageLink('cartCount') cartCount: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  private async load(): Promise<void> {
    if (this.userId <= 0) {
      this.user = null;
      this.loading = false;
      return;
    }
    this.loading = true;
    try {
      this.user = await UserApi.detail(this.userId);
    } catch (err) {
      this.user = null;
      this.toast(`${err}`);
    }
    this.loading = false;
  }

  private async logout(): Promise<void> {
    CartViewModel.clearUser();
    this.user = null;
    this.toast('已退出登录');
  }

  private async autoLogin(): Promise<void> {
    try {
      const user = await UserApi.login(Constants.DEMO_USERNAME, Constants.DEMO_PASSWORD);
      CartViewModel.setCurrentUserId(user.id);
      await CartViewModel.refresh(user.id);
      await this.load();
      this.toast(`已登录 ${user.nickname}`);
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
  }

  @Builder
  entryRow(icon: string, label: string, hint: string, action: () => void) {
    Row() {
      Column() {
        VectorIcon({ path: icon, iconSize: 19, color: Theme.TEXT_SUB })
      }
      .width(28)
      .justifyContent(FlexAlign.Center)

      Text(label)
        .fontSize(14)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)

      Text(hint)
        .fontSize(12)
        .fontColor(Theme.TEXT_HINT)

      Text('›')
        .fontSize(16)
        .fontColor(Theme.TEXT_HINT)
        .margin({ left: 6 })
    }
    .width('100%')
    .height(50)
    .padding({ left: 12, right: 12 })
    .backgroundColor(Theme.CARD)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  build() {
    Column() {
      Column() {
        if (this.user !== null) {
          Row() {
            Column() {
              VectorIcon({ path: Icons.PERSON, iconSize: 30, color: Theme.PRIMARY })
            }
            .width(56)
            .height(56)
            .justifyContent(FlexAlign.Center)
            .borderRadius(28)
            .backgroundColor(Color.White)

            Column() {
              Row() {
                Text(this.user.nickname ?? this.user.username)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)

                Text('WOW 会员')
                  .fontSize(10)
                  .fontColor('#7A4B00')
                  .backgroundColor(Theme.ACCENT)
                  .borderRadius(4)
                  .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  .margin({ left: 8 })
              }
              .alignItems(VerticalAlign.Center)

              Text(this.user.phone ?? '未绑定手机号')
                .fontSize(12)
                .fontColor('#FFD9DE')
                .margin({ top: 6 })
            }
            .layoutWeight(1)
            .margin({ left: 12 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        } else {
          Row() {
            Column() {
              VectorIcon({ path: Icons.PERSON, iconSize: 30, color: '#FFFFFF' })
            }
            .width(56)
            .height(56)
            .justifyContent(FlexAlign.Center)
            .borderRadius(28)
            .backgroundColor('#FFFFFF33')

            Column() {
              Text('未登录')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Text('登录后可下单、查看订单')
                .fontSize(12)
                .fontColor('#FFD9DE')
                .margin({ top: 6 })
            }
            .layoutWeight(1)
            .margin({ left: 12 })
            .alignItems(HorizontalAlign.Start)

            if (!this.loading) {
              Text('登录')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.PRIMARY)
                .textAlign(TextAlign.Center)
                .width(64)
                .height(30)
                .borderRadius(15)
                .backgroundColor(Color.White)
                .onClick(() => {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
                })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: Theme.GAP, right: Theme.GAP, top: 20, bottom: 20 })
      .backgroundColor(Theme.PRIMARY)

      Column() {
        this.entryRow(Icons.RECEIPT, '我的订单', '全部订单', () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/OrderListPage' });
        })
        Divider().color(Theme.DIVIDER).margin({ left: 40 })

        this.entryRow(Icons.LOCATION, '收货地址', '管理地址', () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/AddressPage' });
        })
        Divider().color(Theme.DIVIDER).margin({ left: 40 })

        this.entryRow(Icons.BURGER, '去点餐', `${this.cartCount} 件在购物车`, () => {
          this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
        })
        Divider().color(Theme.DIVIDER).margin({ left: 40 })

        this.entryRow(Icons.KEY, '切换账号 / 注册', '', () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
        })
      }
      .width('100%')
      .margin({ top: 10 })
      .backgroundColor(Theme.CARD)

      Column() {
        Text('演示账号一键登录')
          .fontSize(13)
          .fontColor(Theme.PRIMARY)
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(40)
          .borderRadius(20)
          .border({ width: 1, color: Theme.PRIMARY })
          .onClick(() => {
            this.autoLogin();
          })
          .margin({ top: 20 })

        if (this.userId > 0) {
          Text('退出登录')
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(40)
            .borderRadius(20)
            .border({ width: 1, color: Theme.DIVIDER })
            .onClick(() => {
              this.logout();
            })
            .margin({ top: 10 })
        }
      }
      .width('100%')
      .padding({ left: Theme.GAP, right: Theme.GAP })

      Blank()

      BottomTabBar({ index: 2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
