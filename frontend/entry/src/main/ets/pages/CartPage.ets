import { Theme } from '../common/Constants';
import { CartItem } from '../model/CartItem';
import { Order } from '../model/Order';
import { OrderDetailParams } from '../model/RouteParams';
import { CartApi } from '../api/CartApi';
import { OrderApi } from '../api/OrderApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { ProductThumb } from '../components/ProductThumb';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 购物车页
 *
 * 改数量、删条目都直接打后端接口，改完立即回读列表与汇总，
 * 保证界面上看到的金额永远跟服务端一致（不在前端自己算钱）。
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
      this.errorMsg = `购物车加载失败：${err}`;
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
      this.toast('购物车已清空');
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
      this.toast('购物车是空的');
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
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
  }

  @Builder
  navBar() {
    Row() {
      Text('‹')
        .fontSize(24)
        .fontColor(Theme.TEXT)
        .width(36)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })

      Text('购物车')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text('清空')
        .fontSize(13)
        .fontColor(Theme.TEXT_SUB)
        .width(36)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.clearCart();
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
    .backgroundColor(Theme.CARD)
    .border({ width: { bottom: 1 }, color: Theme.DIVIDER })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  stepper(item: CartItem) {
    Row() {
      Text('−')
        .fontSize(16)
        .fontColor(item.quantity > 1 ? Theme.TEXT : Theme.TEXT_HINT)
        .textAlign(TextAlign.Center)
        .width(26)
        .height(26)
        .borderRadius(13)
        .border({ width: 1, color: Theme.DIVIDER })
        .onClick(() => {
          this.changeQuantity(item, -1);
        })

      Text(`${item.quantity}`)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .constraintSize({ minWidth: 26 })

      Text('+')
        .fontSize(16)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width(26)
        .height(26)
        .borderRadius(13)
        .backgroundColor(Theme.PRIMARY)
        .onClick(() => {
          this.changeQuantity(item, 1);
        })
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.navBar()

      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color(Theme.PRIMARY)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(13).fontColor(Theme.TEXT_SUB).textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column() {
          VectorIcon({ path: Icons.CART, iconSize: 48, color: '#D8D8D8' })
          Text('购物车还是空的')
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .margin({ top: 10 })
          Text('去点餐')
            .fontSize(13)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .width(100)
            .height(32)
            .borderRadius(16)
            .backgroundColor(Theme.PRIMARY)
            .margin({ top: 14 })
            .onClick(() => {
              this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
            })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.items, (item: CartItem) => {
            ListItem() {
              Row() {
                ProductThumb({ image: item.productImage ?? '', thumbSize: 62 })

                Column() {
                  Text(item.productName)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  Text(`¥${item.price}`)
                    .fontSize(13)
                    .fontColor(Theme.PRIMARY)
                    .margin({ top: 6 })

                  Text(`小计 ¥${item.subtotal}`)
                    .fontSize(11)
                    .fontColor(Theme.TEXT_HINT)
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .margin({ left: 10 })
                .alignItems(HorizontalAlign.Start)

                this.stepper(item)
              }
              .width('100%')
              .padding({ left: Theme.GAP, right: Theme.GAP, top: 12, bottom: 12 })
              .backgroundColor(Theme.CARD)
              .alignItems(VerticalAlign.Center)
            }
          }, (item: CartItem) => `${item.id}-${item.quantity}`)

          ListItem() {
            Row() {
              Text('备注')
                .fontSize(13)
                .fontColor(Theme.TEXT_SUB)
                .width(44)
              TextInput({ placeholder: '如：不要生菜、少放冰', text: this.remark })
                .layoutWeight(1)
                .height(38)
                .fontSize(13)
                .backgroundColor('#F7F7F7')
                .borderRadius(8)
                .onChange((value: string) => {
                  this.remark = value;
                })
            }
            .width('100%')
            .padding({ left: Theme.GAP, right: Theme.GAP, top: 10, bottom: 10 })
            .backgroundColor(Theme.CARD)
            .margin({ top: 8 })
            .alignItems(VerticalAlign.Center)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(Theme.BG)
        .scrollBar(BarState.Off)
      }

      Row() {
        Row() {
          Text('合计 ')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
          Text('¥')
            .fontSize(11)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
          Text(`${this.cartAmount.toFixed(2)}`)
            .fontSize(18)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
          Text(`  （${this.cartCount} 件）`)
            .fontSize(11)
            .fontColor(Theme.TEXT_HINT)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Bottom)

        Text(this.submitting ? '提交中…' : '去结算')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(112)
          .height(38)
          .borderRadius(19)
          .backgroundColor(this.items.length > 0 && !this.submitting ? Theme.PRIMARY : '#D0D0D0')
          .onClick(() => {
            if (!this.submitting && this.items.length > 0) {
              this.checkout();
            }
          })
      }
      .width('100%')
      .height(60)
      .padding({ left: Theme.GAP, right: Theme.GAP })
      .backgroundColor(Theme.CARD)
      .border({ width: { top: 1 }, color: Theme.DIVIDER })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
