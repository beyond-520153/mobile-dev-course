import { StoreInfo, Theme } from '../common/Constants';
import { Order } from '../model/Order';
import { OrderItem } from '../model/OrderItem';
import { OrderDetailParams } from '../model/RouteParams';
import { OrderApi } from '../api/OrderApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { ProductThumb } from '../components/ProductThumb';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 我的订单 —— 对齐官方「订单列表」页
 *
 * 顶部白色导航（返回 / 我的订单 / 刷新）
 * 页签：全部 / 待支付 / 进行中 / 已完成（红色短下划线，和官方一致）
 * 订单卡：门店名 + 状态 → 餐品行 → 合计 → 操作按钮（胶囊描边 + 红色实心）
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
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/OrderDetailPage',
        params: new OrderDetailParams(order.id)
      });
    } catch (e) {
      this.toast('页面跳转失败');
    }
  }

  private goMenu(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
    } catch (e) {
      this.toast('页面跳转失败');
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
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/MinePage' });
      } catch (e2) {
        this.toast('返回失败');
      }
    }
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
      Row() {
        VectorIcon({ path: Icons.ARROW_BACK, iconSize: 20, color: Theme.TEXT })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.back())

      Text('我的订单')
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
  tabBar() {
    Row() {
      ForEach(this.filters, (code: string) => {
        Column() {
          Text(this.filterLabel(code))
            .fontSize(13.5)
            .fontWeight(this.filter === code ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.filter === code ? Theme.TEXT : Theme.TEXT_HINT)
          Row()
            .width(16)
            .height(2.6)
            .borderRadius(2)
            .backgroundColor(this.filter === code ? Theme.PRIMARY : Color.Transparent)
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.filter = code;
        })
      }, (code: string) => code)
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: '#F2F2F2' })
  }

  @Builder
  actionButton(label: string, filled: boolean, onTap: () => void) {
    Text(label)
      .fontSize(12.5)
      .fontWeight(filled ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(filled ? '#FFFFFF' : Theme.TEXT_SUB)
      .textAlign(TextAlign.Center)
      .height(30)
      .padding({ left: 15, right: 15 })
      .borderRadius(15)
      .backgroundColor(filled ? Theme.PRIMARY : '#FFFFFF')
      .border({ width: filled ? 0 : 0.5, color: '#D8D8D8' })
      .margin({ left: 8 })
      .onClick(onTap)
  }

  @Builder
  thumbStrip(order: Order) {
    Row() {
      if (order.items.length === 0) {
        Text('（无明细）')
          .fontSize(11.4)
          .fontColor('#B0B0B0')
      } else {
        ForEach(order.items.slice(0, 4), (item: OrderItem) => {
          Column() {
            ProductThumb({ image: item.productImage ?? '', thumbSize: 56 })
          }
          .margin({ right: 8 })
        }, (item: OrderItem) => `${order.id}-${item.id}`)
      }
    }
    .width('100%')
  }

  @Builder
  orderCard(order: Order) {
    Column() {
      Row() {
        VectorIcon({ path: Icons.STORE, iconSize: 14, color: Theme.TEXT })
        Text(StoreInfo.NAME)
          .fontSize(13.5)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
          .margin({ left: 4 })
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(order.statusText)
          .fontSize(12.5)
          .fontWeight(FontWeight.Medium)
          .fontColor(order.status === 'CANCELLED' || order.status === 'COMPLETED'
            ? Theme.TEXT_HINT : Theme.PRIMARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider().color('#F5F5F5').margin({ top: 10, bottom: 10 })

      this.thumbStrip(order)

      Row() {
        Text(`${order.orderNo} · 共 ${order.itemCount} 件`)
          .fontSize(11.4)
          .fontColor(Theme.TEXT_HINT)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('实付')
          .fontSize(11.4)
          .fontColor(Theme.TEXT_SUB)
        Row() {
          Text('¥')
            .fontSize(10.4)
            .fontColor(Theme.TEXT)
            .fontWeight(FontWeight.Bold)
          Text(`${Number(order.payAmount).toFixed(2)}`)
            .fontSize(15.6)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ left: 3 })
      }
      .width('100%')
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Center)

      Row() {
        if (order.pickupCode !== undefined && order.pickupCode.length > 0) {
          Row() {
            Text('取餐码')
              .fontSize(11.4)
              .fontColor(Theme.TEXT_SUB)
            Text(order.pickupCode)
              .fontSize(13.5)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.PRIMARY)
              .margin({ left: 4 })
          }
          .alignItems(VerticalAlign.Center)
        }
        Blank()
        if (order.status === 'PENDING_PAYMENT') {
          this.actionButton('取消订单', false, () => this.cancel(order))
          this.actionButton('去支付', true, () => this.pay(order))
        } else if (order.status === 'PAID') {
          this.actionButton('取消订单', false, () => this.cancel(order))
          this.actionButton('详情', false, () => this.openDetail(order))
        } else {
          this.actionButton('详情', false, () => this.openDetail(order))
        }
      }
      .width('100%')
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 12.5, right: 12.5, top: 13, bottom: 13 })
    .backgroundColor('#FFFFFF')
    .borderRadius(Theme.RADIUS)
    .onClick(() => this.openDetail(order))
  }

  build() {
    Column() {
      this.navBar()
      this.tabBar()

      if (this.loading) {
        Column() {
          LoadingProgress().width(34).height(34).color(Theme.PRIMARY)
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
          VectorIcon({ path: Icons.RECEIPT, iconSize: 46, color: '#D8D8D8' })
          Text('还没有订单')
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
      } else {
        List({ space: 9 }) {
          ForEach(this.visibleOrders(), (order: Order) => {
            ListItem() {
              this.orderCard(order)
            }
          }, (order: Order) => `${order.id}-${order.status}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 8, right: 8, top: 9, bottom: 9 })
        .backgroundColor(Theme.BG)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
