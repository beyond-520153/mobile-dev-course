import { Theme } from '../common/Constants';
import { DateUtil } from '../common/DateUtil';
import { Order } from '../model/Order';
import { OrderDetailParams } from '../model/RouteParams';
import { OrderApi } from '../api/OrderApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { BottomTabBar } from '../components/BottomTabBar';
import { ProductThumb } from '../components/ProductThumb';

/**
 * 订单列表页
 *
 * 顶部按状态筛选（客户端过滤，数据量小不需要后端分页），
 * 每张订单卡按状态给出可执行的动作：支付 / 取消 / 看取餐码。
 */
@Entry
@Component
struct OrderListPage {

  @State orders: Order[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State filter: string = 'ALL';

  @StorageLink('userId') userId: number = 0;

  private filters: string[] = ['ALL', 'PENDING_PAYMENT', 'ONGOING', 'DONE'];

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
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
      this.orders = await OrderApi.listByUser(uid);
      this.errorMsg = '';
    } catch (err) {
      this.errorMsg = `订单加载失败：${err}`;
    }
    this.loading = false;
  }

  private visibleOrders(): Order[] {
    if (this.filter === 'ALL') {
      return this.orders;
    }
    const result: Order[] = [];
    for (let i = 0; i < this.orders.length; i++) {
      const order = this.orders[i];
      if (this.filter === 'PENDING_PAYMENT' && order.status === 'PENDING_PAYMENT') {
        result.push(order);
      } else if (this.filter === 'ONGOING' && (order.status === 'PAID' || order.status === 'READY')) {
        result.push(order);
      } else if (this.filter === 'DONE' && (order.status === 'COMPLETED' || order.status === 'CANCELLED')) {
        result.push(order);
      }
    }
    return result;
  }

  private async pay(order: Order): Promise<void> {
    try {
      const paid: Order = await OrderApi.pay(order.id);
      this.toast(`支付成功，取餐码 ${paid.pickupCode}`);
      await this.load();
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private async cancel(order: Order): Promise<void> {
    try {
      await OrderApi.cancel(order.id);
      this.toast('订单已取消');
      await this.load();
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private openDetail(order: Order): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/OrderDetailPage',
      params: new OrderDetailParams(order.id)
    });
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
  }

  private filterLabel(code: string): string {
    if (code === 'ALL') {
      return '全部';
    }
    if (code === 'PENDING_PAYMENT') {
      return '待支付';
    }
    if (code === 'ONGOING') {
      return '进行中';
    }
    return '已完成';
  }

  @Builder
  navBar() {
    Row() {
      Text('我的订单')
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
    .padding({ left: 4, right: 4 })
    .backgroundColor(Theme.CARD)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  orderCard(order: Order) {
    Column() {
      Row() {
        Text(`订单号 ${order.orderNo}`)
          .fontSize(11)
          .fontColor(Theme.TEXT_HINT)
          .layoutWeight(1)

        Text(order.statusText)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(order.status === 'CANCELLED' ? Theme.TEXT_SUB : Theme.PRIMARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider().color(Theme.DIVIDER).margin({ top: 8, bottom: 8 })

      Row() {
        ProductThumb({
          image: order.items.length > 0 ? (order.items[0].productImage ?? '') : '',
          thumbSize: 54
        })

        Column() {
          Text(order.items.length > 0 ? order.items[0].productName : '（无明细）')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(`共 ${order.itemCount} 件 · ${order.pickupTypeText}`)
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
            .margin({ top: 4 })

          Text(DateUtil.formatDateTime(order.createdAt))
            .fontSize(11)
            .fontColor(Theme.TEXT_HINT)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .margin({ left: 10 })
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text('实付')
            .fontSize(10)
            .fontColor(Theme.TEXT_HINT)
          Text(`¥${order.payAmount}`)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        if (order.pickupCode !== undefined && order.pickupCode.length > 0) {
          Text(`取餐码 ${order.pickupCode}`)
            .fontSize(12)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
        }
        Blank()
        if (order.status === 'PENDING_PAYMENT') {
          Text('取消订单')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(30)
            .borderRadius(15)
            .border({ width: 1, color: Theme.DIVIDER })
            .onClick(() => {
              this.cancel(order);
            })

          Text('立即支付')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(30)
            .borderRadius(15)
            .backgroundColor(Theme.PRIMARY)
            .margin({ left: 8 })
            .onClick(() => {
              this.pay(order);
            })
        } else {
          Text('查看详情')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(30)
            .borderRadius(15)
            .border({ width: 1, color: Theme.DIVIDER })
            .onClick(() => {
              this.openDetail(order);
            })
        }
      }
      .width('100%')
      .margin({ top: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.CARD)
    .borderRadius(10)
    .onClick(() => {
      this.openDetail(order);
    })
  }

  build() {
    Column() {
      this.navBar()

      Row() {
        ForEach(this.filters, (code: string) => {
          Text(this.filterLabel(code))
            .fontSize(13)
            .fontWeight(this.filter === code ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.filter === code ? Color.White : Theme.TEXT_SUB)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(30)
            .borderRadius(15)
            .backgroundColor(this.filter === code ? Theme.PRIMARY : Color.Transparent)
            .onClick(() => {
              this.filter = code;
            })
        }, (code: string) => code)
      }
      .width('100%')
      .padding({ left: Theme.GAP, right: Theme.GAP, top: 8, bottom: 8 })
      .backgroundColor(Theme.CARD)
      .border({ width: { bottom: 1 }, color: Theme.DIVIDER })

      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color(Theme.PRIMARY)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(13).fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.visibleOrders().length === 0) {
        Column() {
          Text('🧾').fontSize(44)
          Text('还没有订单')
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
        List({ space: 10 }) {
          ForEach(this.visibleOrders(), (order: Order) => {
            ListItem() {
              this.orderCard(order)
            }
          }, (order: Order) => `${order.id}-${order.status}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: Theme.GAP, right: Theme.GAP, top: 10, bottom: 10 })
        .backgroundColor(Theme.BG)
        .scrollBar(BarState.Off)
      }

      BottomTabBar({ index: 1 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
