@Entry
@Component
struct MinePage {
  build() {
    Column() {
      Text('我的')
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
