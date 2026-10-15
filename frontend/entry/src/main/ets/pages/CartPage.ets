@Entry
@Component
struct CartPage {
  build() {
    Column() {
      Text('购物车')
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
