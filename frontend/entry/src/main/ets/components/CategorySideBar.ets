import { Theme } from '../common/Constants';

/**
 * 左侧分类栏
 *
 * 选中项：白底 + 红字加粗 + 左侧红色竖条，与肯德基小程序一致。
 */
@Component
export struct CategorySideBar {

  @Prop categories: string[] = [];
  @Prop selected: number = 0;

  /** 点分类时回调给页面，由页面把右侧列表滚到对应位置 */
  onSelect: (index: number) => void = () => {
  };

  build() {
    List() {
      ForEach(this.categories, (name: string, i: number) => {
        ListItem() {
          Row() {
            Column()
              .width(3)
              .height(18)
              .borderRadius(2)
              .backgroundColor(i === this.selected ? Theme.PRIMARY : Color.Transparent)

            Text(name)
              .fontSize(13)
              .fontColor(i === this.selected ? Theme.PRIMARY : Theme.TEXT)
              .fontWeight(i === this.selected ? FontWeight.Bold : FontWeight.Normal)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ left: 6 })
              .layoutWeight(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 0, right: 8 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(i === this.selected ? Theme.CARD : Theme.SIDEBAR_BG)
          .onClick(() => {
            this.onSelect(i);
          })
        }
      }, (name: string, i: number) => `${i}-${name}`)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.SIDEBAR_BG)
  }
}
