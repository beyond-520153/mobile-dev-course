import { Theme } from '../common/Constants';

/** 底部导航项 */
export interface TabItem {
  label: string;
  icon: string;
  url: string;
}

/**
 * 底部导航栏 —— 点餐 / 订单 / 我的
 *
 * 用 replaceUrl 而不是 pushUrl：切 tab 不应该把页面堆起来，
 * 否则用户连点几次返回都退不出去。
 */
@Component
export struct BottomTabBar {

  /** 当前高亮的 tab 下标 */
  @Prop index: number = 0;

  private tabs: TabItem[] = [
    { label: '点餐', icon: '🍔', url: 'pages/Index' },
    { label: '订单', icon: '🧾', url: 'pages/OrderListPage' },
    { label: '我的', icon: '👤', url: 'pages/MinePage' }
  ];

  build() {
    Row() {
      ForEach(this.tabs, (item: TabItem, i: number) => {
        Column() {
          Text(item.icon)
            .fontSize(20)

          Text(item.label)
            .fontSize(11)
            .fontColor(i === this.index ? Theme.PRIMARY : Theme.TEXT_SUB)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (i !== this.index) {
            this.getUIContext().getRouter().replaceUrl({ url: item.url });
          }
        })
      }, (item: TabItem) => item.url)
    }
    .width('100%')
    .height(52)
    .backgroundColor(Theme.CARD)
    .border({ width: { top: 1 }, color: Theme.DIVIDER })
  }
}
