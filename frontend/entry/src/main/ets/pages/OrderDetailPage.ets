@Entry
@Component
struct OrderDetailPage {
  build() {
    Column() {
      Text('订单详情')
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
