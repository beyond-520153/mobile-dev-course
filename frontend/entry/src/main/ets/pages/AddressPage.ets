@Entry
@Component
struct AddressPage {
  build() {
    Column() {
      Text('收货地址')
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
