@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('首页 · 点餐')
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
