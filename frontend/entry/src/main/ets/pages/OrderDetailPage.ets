import { Theme } from '../common/Constants';
import { DateUtil } from '../common/DateUtil';
import { Order } from '../model/Order';
import { OrderItem } from '../model/OrderItem';
import { OrderDetailParams } from '../model/RouteParams';
import { OrderApi } from '../api/OrderApi';
import { ProductThumb } from '../components/ProductThumb';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 订单详情页
 *
 * 顶部一块红色状态区：已支付/待取餐时把取餐码放大展示，这是到店取餐的关键信息。
 */
@Entry
@Component
struct OrderDetailPage {

  @State order: Order | null = null;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  private orderId: number = 0;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as OrderDetailParams;
    if (params !== undefined && params !== null) {
      this.orderId = params.orderId;
    }
    this.load();
  }

  private async load(): Promise<void> {
    if (this.orderId <= 0) {
      this.errorMsg = '缺少订单号参数';
      this.loading = false;
      return;
    }
    this.loading = true;
    try {
      this.order = await OrderApi.detail(this.orderId);
      this.errorMsg = '';
    } catch (err) {
      this.errorMsg = `订单加载失败：${err}`;
    }
    this.loading = false;
  }

  private async pay(): Promise<void> {
    if (this.order === null) {
      return;
    }
    try {
      this.order = await OrderApi.pay(this.order.id);
      this.toast(`支付成功，取餐码 ${this.order.pickupCode}`);
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private async cancel(): Promise<void> {
    if (this.order === null) {
      return;
    }
    try {
      this.order = await OrderApi.cancel(this.order.id);
      this.toast('订单已取消');
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
  }

  @Builder
  navBar() {
    Row() {
      // 返回：矢量箭头（原来是文字字符 ‹）
      Row() {
        VectorIcon({ path: Icons.ARROW_BACK, iconSize: 18, color: Theme.TEXT })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.getUIContext().getRouter().back();
      })

      Text('订单详情')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text('刷新')
        .fontSize(13)
        .fontColor(Theme.TEXT_SUB)
        .width(44)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.load();
        })
    }
    .width('100%')
    .height(48)
    .backgroundColor(Theme.CARD)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  statusBanner(order: Order) {
    Column() {
      Text(order.statusText)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)

      if (order.pickupCode !== undefined && order.pickupCode.length > 0) {
        Text('取餐码')
          .fontSize(11)
          .fontColor('#FFD9DE')
          .margin({ top: 12 })

        Text(order.pickupCode)
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      } else {
        Text(order.status === 'CANCELLED' ? '订单已取消，可重新下单' : '支付后会生成取餐码')
          .fontSize(12)
          .fontColor('#FFD9DE')
          .margin({ top: 10 })
      }

      Text(`${order.pickupTypeText} · 共 ${order.itemCount} 件`)
        .fontSize(12)
        .fontColor('#FFD9DE')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding({ top: 20, bottom: 20 })
    .backgroundColor(Theme.PRIMARY)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  itemRow(item: OrderItem) {
    Row() {
      ProductThumb({ image: item.productImage ?? '', thumbSize: 54 })

      Column() {
        Text(item.productName)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(`¥${item.price} × ${item.quantity}`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)

      Text(`¥${item.subtotal}`)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .width(72)
      Text(value)
        .fontSize(12)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Top)
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
      } else if (this.order === null) {
        Column() {
          Text(this.errorMsg.length > 0 ? this.errorMsg : '订单不存在')
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.statusBanner(this.order)

            Column() {
              Row() {
                Text('餐品明细')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .layoutWeight(1)
                Text(`共 ${this.order.itemCount} 件`)
                  .fontSize(11)
                  .fontColor(Theme.TEXT_HINT)
              }
              .width('100%')

              ForEach(this.order.items, (item: OrderItem) => {
                this.itemRow(item)
              }, (item: OrderItem) => `${item.id}`)

              Divider().color(Theme.DIVIDER).margin({ top: 6, bottom: 6 })

              Row() {
                Text('商品金额')
                  .fontSize(12)
                  .fontColor(Theme.TEXT_SUB)
                  .layoutWeight(1)
                Text(`¥${this.order.totalAmount}`)
                  .fontSize(12)
                  .fontColor(Theme.TEXT)
              }
              .width('100%')
              .padding({ top: 3, bottom: 3 })
              .alignItems(VerticalAlign.Center)

              if (this.order.deliveryFee > 0) {
                Row() {
                  Text('外送费')
                    .fontSize(12)
                    .fontColor(Theme.TEXT_SUB)
                    .layoutWeight(1)
                  Text(`¥${this.order.deliveryFee}`)
                    .fontSize(12)
                    .fontColor(Theme.TEXT)
                }
                .width('100%')
                .padding({ top: 3, bottom: 3 })
                .alignItems(VerticalAlign.Center)
              }

              if (this.order.discountAmount > 0) {
                Row() {
                  Text('大神卡优惠')
                    .fontSize(12)
                    .fontColor(Theme.TEXT_SUB)
                    .layoutWeight(1)
                  Text(`-¥${this.order.discountAmount}`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.PRIMARY)
                }
                .width('100%')
                .padding({ top: 3, bottom: 3 })
                .alignItems(VerticalAlign.Center)

                if (this.order.benefitDetail !== undefined) {
                  Text(this.order.benefitDetail)
                    .fontSize(10)
                    .fontColor(Theme.TEXT_HINT)
                    .width('100%')
                    .margin({ top: 2, bottom: 4 })
                }
              }

              Divider().color(Theme.DIVIDER).margin({ top: 6, bottom: 6 })

              Row() {
                Text('实付')
                  .fontSize(13)
                  .fontColor(Theme.TEXT_SUB)
                  .layoutWeight(1)
                Text(`¥${this.order.payAmount}`)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.PRIMARY)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(Theme.CARD)
            .borderRadius(10)
            .margin({ top: 10 })
            .alignItems(HorizontalAlign.Start)

            Column() {
              this.infoRow('订单号', this.order.orderNo)
              this.infoRow('下单时间', DateUtil.formatDateTime(this.order.createdAt))
              this.infoRow('取餐方式', this.order.pickupTypeText)
              if (this.order.payTime !== undefined) {
                this.infoRow('支付时间', DateUtil.formatDateTime(this.order.payTime))
              }
              this.infoRow('备注', this.order.remark === undefined || this.order.remark.length === 0
                ? '无' : this.order.remark)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(Theme.CARD)
            .borderRadius(10)
            .margin({ top: 10 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: Theme.GAP, right: Theme.GAP, bottom: 20 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        if (this.order.status === 'PENDING_PAYMENT') {
          Row() {
            Text('取消订单')
              .fontSize(14)
              .fontColor(Theme.TEXT_SUB)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(40)
              .borderRadius(20)
              .border({ width: 1, color: Theme.DIVIDER })
              .onClick(() => {
                this.cancel();
              })

            Text('立即支付')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(40)
              .borderRadius(20)
              .backgroundColor(Theme.PRIMARY)
              .margin({ left: 10 })
              .onClick(() => {
                this.pay();
              })
          }
          .width('100%')
          .padding({ left: Theme.GAP, right: Theme.GAP, top: 8, bottom: 8 })
          .backgroundColor(Theme.CARD)
          .border({ width: { top: 1 }, color: Theme.DIVIDER })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
