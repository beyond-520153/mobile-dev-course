import { StoreInfo, Theme, pickupLabel } from '../common/Constants';
import { CartItem } from '../model/CartItem';
import { Order } from '../model/Order';
import { OrderDetailParams } from '../model/RouteParams';
import { CartApi } from '../api/CartApi';
import { OrderApi } from '../api/OrderApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { ProductThumb } from '../components/ProductThumb';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 购物车 —— 对齐官方「我的餐车」页
 *
 * 结构（自上而下，与官方一致）：
 *   白色导航（返回 / 购物车 / 清空）
 *   门店条（门店名 + 取餐方式）
 *   商品白卡（缩略图 / 名称 / 单价 / 红色步进器）
 *   备注卡
 *   底部结算条（合计金额 + 红色胶囊按钮）
 *
 * 所有金额都以后端返回为准，前端不自己算钱。
 */
@Entry
@Component
struct CartPage {

  @State items: CartItem[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State remark: string = '';
  @State submitting: boolean = false;

  @StorageLink('userId') userId: number = 0;
  @StorageLink('cartCount') cartCount: number = 0;
  @StorageLink('cartAmount') cartAmount: number = 0;
  @StorageLink('pickupType') pickupType: string = 'PICKUP';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const uid = CartViewModel.currentUserId();
    if (uid <= 0) {
      this.errorMsg = '请先登录';
      this.loading = false;
      return;
    }
    this.loading = true;
    try {
      this.items = await CartApi.list(uid);
      await CartViewModel.refresh(uid);
      this.errorMsg = '';
    } catch (err) {
      this.errorMsg = `餐车加载失败：${err}`;
    }
    this.loading = false;
  }

  /** delta 为 +1 / -1；减到 0 时后端会把条目删掉 */
  private async changeQuantity(item: CartItem, delta: number): Promise<void> {
    const uid = CartViewModel.currentUserId();
    const target = item.quantity + delta;
    try {
      if (target <= 0) {
        await CartApi.remove(item.id, uid);
      } else {
        await CartApi.updateQuantity(item.id, target);
      }
      await this.load();
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private async clearCart(): Promise<void> {
    try {
      await CartApi.clear(CartViewModel.currentUserId());
      await this.load();
      this.toast('餐车已清空');
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  /**
   * 去结算：下单 + 支付
   *
   * 下单接口以服务端购物车为准重新算价，返回订单后再调支付接口拿取餐码。
   * 演示环境没有接真实支付，所以下单后直接调支付。
   */
  private async checkout(): Promise<void> {
    const uid = CartViewModel.currentUserId();
    if (uid <= 0) {
      this.toast('请先登录');
      return;
    }
    if (this.items.length === 0) {
      this.toast('餐车是空的');
      return;
    }
    this.submitting = true;
    try {
      const order: Order = await OrderApi.create({
        userId: uid,
        pickupType: 'PICKUP',
        remark: this.remark
      });
      const paid: Order = await OrderApi.pay(order.id);
      await CartViewModel.refresh(uid);
      this.toast(`支付成功，取餐码 ${paid.pickupCode}`);
      this.getUIContext().getRouter().replaceUrl({
        url: 'pages/OrderDetailPage',
        params: new OrderDetailParams(paid.id)
      });
    } catch (err) {
      this.toast(`${err}`);
    }
    this.submitting = false;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
    } catch (e) {
      // 忽略
    }
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (e) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
      } catch (e2) {
        this.toast('返回失败');
      }
    }
  }

  private goMenu(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
    } catch (e) {
      this.toast('页面跳转失败');
    }
  }

  @Builder
  navBar() {
    Row() {
      Row() {
        VectorIcon({ path: Icons.ARROW_BACK, iconSize: 20, color: Theme.TEXT })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.back())

      Text('购物车')
        .fontSize(16.6)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text('清空')
        .fontSize(12.5)
        .fontColor(Theme.TEXT_SUB)
        .width(44)
        .textAlign(TextAlign.End)
        .onClick(() => this.clearCart())
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  /** 门店条：官方在餐车顶部固定显示当前门店与取餐方式 */
  @Builder
  storeBar() {
    Row() {
      VectorIcon({ path: Icons.STORE, iconSize: 15, color: Theme.PRIMARY })
      Text(StoreInfo.SHORT)
        .fontSize(13.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .margin({ left: 5 })
        .layoutWeight(1)
      Text(pickupLabel(this.pickupType))
        .fontSize(11.4)
        .fontColor(Theme.TEXT_SUB)
      VectorIcon({ path: Icons.CHEVRON, iconSize: 13, color: '#C9C9C9' })
        .margin({ left: 2 })
    }
    .width('100%')
    .height(44)
    .padding({ left: 12.5, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: '#F2F2F2' })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  stepper(item: CartItem) {
    Row() {
      // 减号：白底细边圆，和官方一致
      Stack() {
        Row() {
          VectorIcon({
            path: Icons.MINUS,
            iconSize: 11,
            color: item.quantity > 1 ? Theme.TEXT : '#CFCFCF'
          })
        }
        .width(22)
        .height(22)
        .borderRadius(11)
        .border({ width: 0.5, color: item.quantity > 1 ? '#D8D8D8' : '#EAEAEA' })
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.changeQuantity(item, -1))
      }
      .width(24)
      .height(24)

      Text(`${item.quantity}`)
        .fontSize(13.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .textAlign(TextAlign.Center)
        .constraintSize({ minWidth: 24 })

      Stack() {
        Row() {
          VectorIcon({ path: Icons.PLUS, iconSize: 11, color: '#FFFFFF' })
        }
        .width(22)
        .height(22)
        .borderRadius(11)
        .backgroundColor(Theme.PRIMARY)
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.changeQuantity(item, 1))
      }
      .width(24)
      .height(24)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  emptyState() {
    Column() {
      VectorIcon({ path: Icons.CART, iconSize: 46, color: '#D8D8D8' })
      Text('餐车还是空的')
        .fontSize(13.5)
        .fontColor(Theme.TEXT_SUB)
        .margin({ top: 12 })
      Text('去点餐')
        .fontSize(12.5)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .width(96)
        .height(32)
        .borderRadius(16)
        .backgroundColor(Theme.PRIMARY)
        .margin({ top: 16 })
        .onClick(() => this.goMenu())
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      this.navBar()
      this.storeBar()

      if (this.loading) {
        Column() {
          LoadingProgress().width(34).height(34).color(Theme.PRIMARY)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg)
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        this.emptyState()
      } else {
        Scroll() {
          Column() {
            Column() {
              ForEach(this.items, (item: CartItem, index: number) => {
                Row() {
                  ProductThumb({ image: item.productImage ?? '', thumbSize: 64 })

                  Column() {
                    Text(item.productName)
                      .fontSize(13.5)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')

                    Text('标准')
                      .fontSize(11.4)
                      .fontColor(Theme.TEXT_HINT)
                      .margin({ top: 3 })

                    Row() {
                      Text(`¥${Number(item.price).toFixed(2)}`)
                        .fontSize(14.6)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.PRIMARY)
                        .layoutWeight(1)
                      this.stepper(item)
                    }
                    .width('100%')
                    .margin({ top: 6 })
                    .alignItems(VerticalAlign.Center)
                  }
                  .layoutWeight(1)
                  .margin({ left: 10 })
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding({ left: 12.5, right: 12.5, top: 13, bottom: 13 })
                .alignItems(VerticalAlign.Top)

                if (index < this.items.length - 1) {
                  Divider()
                    .color('#F5F5F5')
                    .margin({ left: 86.5, right: 12.5 })
                }
              }, (item: CartItem) => `${item.id}-${item.quantity}`)
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(Theme.RADIUS)
            .margin({ top: 9 })

            Column() {
              Row() {
                Text('备注')
                  .fontSize(13)
                  .fontColor(Theme.TEXT)
                  .width(52)
                TextInput({ placeholder: '如：不要生菜、少放冰', text: this.remark })
                  .layoutWeight(1)
                  .height(34)
                  .padding(0)
                  .fontSize(12.5)
                  .placeholderColor('#B0B0B0')
                  .backgroundColor(Color.Transparent)
                  .onChange((value: string) => {
                    this.remark = value;
                  })
              }
              .width('100%')
              .height(46)
              .alignItems(VerticalAlign.Center)

              Divider().color('#F5F5F5')

              Row() {
                Text('取餐方式')
                  .fontSize(13)
                  .fontColor(Theme.TEXT)
                  .layoutWeight(1)
                Text(pickupLabel(this.pickupType))
                  .fontSize(12.5)
                  .fontColor(Theme.TEXT_SUB)
                VectorIcon({ path: Icons.CHEVRON, iconSize: 13, color: '#C9C9C9' })
                  .margin({ left: 2 })
              }
              .width('100%')
              .height(46)
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding({ left: 12.5, right: 12.5 })
            .backgroundColor('#FFFFFF')
            .borderRadius(Theme.RADIUS)
            .margin({ top: 9 })

            Text('共 ' + this.cartCount + ' 件商品')
              .fontSize(11.4)
              .fontColor(Theme.TEXT_HINT)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 16, bottom: 16 })
          }
          .width('100%')
          .padding({ left: 8, right: 8, bottom: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(Theme.BG)

        // 底部结算条
        Row() {
          Column() {
            Row() {
              Text('¥')
                .fontSize(11.4)
                .fontColor(Theme.PRIMARY)
                .fontWeight(FontWeight.Bold)
              Text(`${this.cartAmount.toFixed(2)}`)
                .fontSize(19.8)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.PRIMARY)
            }
            .alignItems(VerticalAlign.Bottom)

            Text(`共 ${this.cartCount} 件`)
              .fontSize(10.4)
              .fontColor(Theme.TEXT_HINT)
              .margin({ top: 1 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.submitting ? '提交中…' : '去结算')
            .fontSize(14.6)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width(118)
            .height(40)
            .borderRadius(20)
            .backgroundColor(this.items.length > 0 && !this.submitting ? Theme.PRIMARY : '#D0D0D0')
            .onClick(() => {
              if (!this.submitting && this.items.length > 0) {
                this.checkout();
              }
            })
        }
        .width('100%')
        .height(64)
        .padding({ left: 12.5, right: 12.5 })
        .backgroundColor('#FFFFFF')
        .border({ width: { top: 0.5 }, color: '#F2F2F2' })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
