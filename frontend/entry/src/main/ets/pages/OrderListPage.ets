@Entry
@Component
struct OrderListPage {
  build() {
    Column() {
      Text('我的订单')
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
