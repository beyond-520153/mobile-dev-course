import { StoreInfo, Theme, pickupLabel } from '../common/Constants';
import { DateUtil } from '../common/DateUtil';
import { Order } from '../model/Order';
import { OrderItem } from '../model/OrderItem';
import { OrderDetailParams } from '../model/RouteParams';
import { OrderApi } from '../api/OrderApi';
import { ProductThumb } from '../components/ProductThumb';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 订单详情 —— 对齐官方「订单详情」页
 *
 * 顶部红色状态区：状态文案 + 取餐码大字（到店取餐的关键信息）
 * 白色卡片：门店信息 / 餐品明细 / 金额明细 / 订单信息
 * 待支付时底部固定「取消订单 + 立即支付」
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
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/OrderListPage' });
      } catch (e2) {
        this.toast('返回失败');
      }
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

      Text('订单详情')
        .fontSize(16.6)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text('刷新')
        .fontSize(12.5)
        .fontColor(Theme.TEXT_SUB)
        .width(44)
        .textAlign(TextAlign.End)
        .onClick(() => this.load())
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  statusBanner(order: Order) {
    Column() {
      Text(order.statusText)
        .fontSize(16.6)
        .fontWeight(FontWeight.Bold)
        .fontColor(order.status === 'CANCELLED' ? Theme.TEXT_SUB : Theme.TEXT)

      if (order.pickupCode !== undefined && order.pickupCode.length > 0) {
        Row() {
          Text('取餐码')
            .fontSize(12.5)
            .fontColor(Theme.TEXT_SUB)
          Text(order.pickupCode)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .letterSpacing(2.5)
            .margin({ left: 6 })
        }
        .alignItems(VerticalAlign.Center)
        .margin({ top: 10 })
      } else {
        Text(order.status === 'CANCELLED' ? '订单已取消，可重新下单' : '支付后会生成取餐码')
          .fontSize(12.5)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 8 })
      }

      Text(`${pickupLabel(order.pickupType)} · 共 ${order.itemCount} 件`)
        .fontSize(11.4)
        .fontColor(Theme.TEXT_HINT)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding({ top: 20, bottom: 20, left: 12.5, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .borderRadius(Theme.RADIUS)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  titleBar(title: string, extra: string) {
    Row() {
      Text(title)
        .fontSize(14.6)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
      Text(extra)
        .fontSize(11.4)
        .fontColor(Theme.TEXT_HINT)
    }
    .width('100%')
    .margin({ bottom: 4 })
  }

  @Builder
  itemRow(item: OrderItem) {
    Row() {
      ProductThumb({ image: item.productImage ?? '', thumbSize: 52 })

      Column() {
        Text(item.productName)
          .fontSize(13.5)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(`¥${Number(item.price).toFixed(2)} × ${item.quantity}`)
          .fontSize(11.4)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)

      Text(`¥${Number(item.subtotal).toFixed(2)}`)
        .fontSize(13.5)
        .fontWeight(FontWeight.Medium)
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
        .fontSize(12.5)
        .fontColor(Theme.TEXT_SUB)
        .width(72)
      Text(value)
        .fontSize(12.5)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  moneyRow(label: string, value: string, highlight: boolean) {
    Row() {
      Text(label)
        .fontSize(12.5)
        .fontColor(highlight ? Theme.TEXT : Theme.TEXT_SUB)
        .layoutWeight(1)
      Text(value)
        .fontSize(highlight ? 15.6 : 12.5)
        .fontWeight(highlight ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(highlight ? Theme.PRIMARY : Theme.TEXT)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.navBar()

      if (this.loading) {
        Column() {
          LoadingProgress().width(34).height(34).color(Theme.PRIMARY)
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

            // 门店信息
            Column() {
              this.titleBar('取餐门店', '')
              Row() {
                VectorIcon({ path: Icons.STORE, iconSize: 15, color: Theme.PRIMARY })
                Text(StoreInfo.SHORT)
                  .fontSize(13.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.TEXT)
                  .margin({ left: 5 })
                  .layoutWeight(1)
                Text(StoreInfo.HOURS)
                  .fontSize(11.4)
                  .fontColor(Theme.TEXT_HINT)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Text(StoreInfo.ADDR)
                .fontSize(11.4)
                .fontColor(Theme.TEXT_SUB)
                .lineHeight(17)
                .margin({ top: 5 })
                .width('100%')
            }
            .width('100%')
            .padding({ left: 12.5, right: 12.5, top: 13, bottom: 13 })
            .backgroundColor('#FFFFFF')
            .borderRadius(Theme.RADIUS)
            .margin({ top: 9 })
            .alignItems(HorizontalAlign.Start)

            // 餐品明细
            Column() {
              this.titleBar('餐品明细', `共 ${this.order.itemCount} 件`)

              ForEach(this.order.items, (item: OrderItem) => {
                this.itemRow(item)
              }, (item: OrderItem) => `${item.id}`)
            }
            .width('100%')
            .padding({ left: 12.5, right: 12.5, top: 13, bottom: 13 })
            .backgroundColor('#FFFFFF')
            .borderRadius(Theme.RADIUS)
            .margin({ top: 9 })
            .alignItems(HorizontalAlign.Start)

            // 金额明细
            Column() {
              this.moneyRow('商品金额', `¥${Number(this.order.totalAmount).toFixed(2)}`, false)
              this.moneyRow('优惠', '¥0.00', false)
              this.moneyRow('实付金额', `¥${Number(this.order.payAmount).toFixed(2)}`, true)
            }
            .width('100%')
            .padding({ left: 12.5, right: 12.5, top: 9, bottom: 9 })
            .backgroundColor('#FFFFFF')
            .borderRadius(Theme.RADIUS)
            .margin({ top: 9 })
            .alignItems(HorizontalAlign.Start)

            // 订单信息
            Column() {
              this.titleBar('订单信息', '')
              this.infoRow('订单号', this.order.orderNo)
              this.infoRow('下单时间', DateUtil.formatDateTime(this.order.createdAt))
              this.infoRow('取餐方式', pickupLabel(this.order.pickupType))
              if (this.order.payTime !== undefined) {
                this.infoRow('支付时间', DateUtil.formatDateTime(this.order.payTime))
              }
              this.infoRow('备注', this.order.remark === undefined || this.order.remark.length === 0
                ? '无' : this.order.remark)
            }
            .width('100%')
            .padding({ left: 12.5, right: 12.5, top: 13, bottom: 13 })
            .backgroundColor('#FFFFFF')
            .borderRadius(Theme.RADIUS)
            .margin({ top: 9 })
            .alignItems(HorizontalAlign.Start)

            Text('KFC 点餐 · 课程设计演示')
              .fontSize(10.4)
              .fontColor('#C9C9C9')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 16, bottom: 18 })
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 9 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(Theme.BG)

        if (this.order.status === 'PENDING_PAYMENT') {
          Row() {
            Text('取消订单')
              .fontSize(14.6)
              .fontColor(Theme.TEXT_SUB)
              .textAlign(TextAlign.Center)
              .width(110)
              .height(40)
              .borderRadius(20)
              .border({ width: 0.5, color: '#D8D8D8' })
              .onClick(() => this.cancel())

            Blank()

            Row() {
              Text('¥')
                .fontSize(11.4)
                .fontColor(Theme.PRIMARY)
                .fontWeight(FontWeight.Bold)
              Text(`${Number(this.order.payAmount).toFixed(2)}`)
                .fontSize(18.7)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.PRIMARY)
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ right: 10 })

            Text('立即支付')
              .fontSize(14.6)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .textAlign(TextAlign.Center)
              .width(112)
              .height(40)
              .borderRadius(20)
              .backgroundColor(Theme.PRIMARY)
              .onClick(() => this.pay())
          }
          .width('100%')
          .height(64)
          .padding({ left: 12.5, right: 12.5 })
          .backgroundColor('#FFFFFF')
          .border({ width: { top: 0.5 }, color: '#F2F2F2' })
          .alignItems(VerticalAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
