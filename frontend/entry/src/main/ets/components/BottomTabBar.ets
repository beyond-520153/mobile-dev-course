import { Theme } from '../common/Constants';
import { Icons, VectorIcon } from './VectorIcon';

/** 底部导航项 */
export interface TabItem {
  label: string;
  path: string;
  url: string;
}

/**
 * 底部导航栏 —— 点餐 / 订单 / 我的
 *
 * 图标用矢量图形（Icons）画，不再用 emoji：emoji 在不同设备上字体不同，
 * 有的机型渲染成彩色表情包，和整体 UI 不搭。
 *
 * 用 replaceUrl 而不是 pushUrl：切 tab 不应该把页面堆起来，
 * 否则用户连点几次返回都退不出去。
 */
@Component
export struct BottomTabBar {

  /** 当前高亮的 tab 下标 */
  @Prop index: number = 0;

  private tabs: TabItem[] = [
    { label: '点餐', path: Icons.BURGER, url: 'pages/Index' },
    { label: '订单', path: Icons.RECEIPT, url: 'pages/OrderListPage' },
    { label: '我的', path: Icons.PERSON, url: 'pages/MinePage' }
  ];

  build() {
    Row() {
      ForEach(this.tabs, (item: TabItem, i: number) => {
        Column() {
          VectorIcon({
            path: item.path,
            iconSize: 21,
            color: i === this.index ? Theme.PRIMARY : Theme.TEXT_SUB
          })

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
