import { Theme, Constants } from '../common/Constants';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 取餐方式入口页（应用启动页）
 *
 * 仿肯德基小程序的门店首页版式：
 *   红色渐变头部（品牌 + 门店） → 招牌套餐 hero 卡 → 两张取餐方式入口卡 → 门店信息。
 *
 * 点「外送到家」或「到店自取」后进入的**是同一个点餐页**（pages/Index），
 * 两者唯一的差别是把选择结果写进 AppStorage 的 pickupType，点餐页顶部据此显示取餐方式。
 */
@Entry
@Component
struct EntryPage {

  /** 头部装饰用的浅色圆，避免整块纯红显得单调 */
  private readonly HERO_IMAGE: string = '/images/products/100129693.jpg';

  /** 记住上次选过的取餐方式，回来时给出选中态 */
  @StorageLink('pickupType') pickupType: string = 'PICKUP';

  aboutToAppear(): void {
    // 入口页不做网络请求，菜单由点餐页自己拉；这里只保证 pickupType 有值
    if (this.pickupType.length === 0) {
      this.pickupType = 'PICKUP';
    }
  }

  /** 选好取餐方式 → 进点餐页（两处入口同一个页面） */
  private enter(type: string): void {
    this.pickupType = type;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Index' });
  }

  private heroUrl(): string {
    return Constants.BASE_URL + this.HERO_IMAGE;
  }

  /* ------------------------------ 头部 ------------------------------ */
  @Builder
  header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 装饰：右上角半透明大圆 + 左下角小圆，纯装饰不响应点击
      Circle()
        .width(170)
        .height(170)
        .fill('#FFFFFF12')
        .offset({ x: 55, y: -70 })
      Circle()
        .width(90)
        .height(90)
        .fill('#FFFFFF0D')
        .offset({ x: 12, y: 96 })

      Column() {
        Row() {
          Column() {
            Text('KFC 点餐')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text('好炸鸡 · 现点现做')
              .fontSize(12)
              .fontColor('#FFD2D9')
              .margin({ top: 5 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Row() {
            Text('浙江农林大学店')
              .fontSize(12)
              .fontColor(Color.White)
            VectorIcon({ path: Icons.LOCATION, iconSize: 13, color: '#FFFFFFCC' })
              .margin({ left: 3 })
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(14)
          .backgroundColor('#FFFFFF26')
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 招牌套餐 hero
        Row() {
          Image(this.heroUrl())
            .width(96)
            .height(96)
            .borderRadius(14)
            .objectFit(ImageFit.Cover)
            .backgroundColor(Theme.THUMB_BG)

          Column() {
            Text('本店招牌')
              .fontSize(10)
              .fontColor('#B3001F')
              .backgroundColor(Theme.ACCENT)
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })

            Text('肉霸堡双人餐')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
              .margin({ top: 8 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text('双堡组合 + 黄金薯条 + 冰爽可乐')
              .fontSize(11)
              .fontColor(Theme.TEXT_SUB)
              .margin({ top: 5 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Row() {
              Text('¥')
                .fontSize(12)
                .fontColor(Theme.PRIMARY)
                .fontWeight(FontWeight.Bold)
              Text('39.9')
                .fontSize(20)
                .fontColor(Theme.PRIMARY)
                .fontWeight(FontWeight.Bold)
              Text('起')
                .fontSize(11)
                .fontColor(Theme.TEXT_SUB)
                .margin({ left: 2 })
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ top: 6 })
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.CARD)
        .borderRadius(16)
        .shadow({ radius: 14, color: '#22000000', offsetX: 0, offsetY: 4 })
        .margin({ top: 18 })
      }
      .width('100%')
      .padding({ left: Theme.GAP + 4, right: Theme.GAP + 4, top: 18, bottom: 26 })
    }
    .width('100%')
    .linearGradient({
      angle: 175,
      colors: [['#E4002B', 0.0], ['#A30020', 1.0]]
    })
  }

  /* -------------------------- 取餐方式入口卡 -------------------------- */
  @Builder
  entryCard(title: string, desc: string, tag: string, icon: string, tint: string, type: string,
    topGap: number) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor(tint)
        VectorIcon({ path: icon, iconSize: 26, color: Theme.PRIMARY })
      }
      .width(48)
      .height(48)

      Column() {
        Row() {
          Text(title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
          Text(tag)
            .fontSize(10)
            .fontColor(Theme.PRIMARY)
            .borderRadius(4)
            .border({ width: 1, color: '#FFC9D4' })
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .margin({ left: 8 })
        }
        .alignItems(VerticalAlign.Center)

        Text(desc)
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 6 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .margin({ left: 14 })
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(22)
        .fontColor(Theme.TEXT_HINT)
        .margin({ left: 6 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.CARD)
    .borderRadius(14)
    .border({ width: 1, color: this.pickupType === type ? '#FFC9D4' : '#00000000' })
    .shadow({ radius: 10, color: '#14000000', offsetX: 0, offsetY: 2 })
    .margin({ top: topGap })
    .onClick(() => {
      this.enter(type);
    })
  }

  /* ------------------------------ 门店信息 ------------------------------ */
  @Builder
  storeInfo(topGap: number) {
    Row() {
      VectorIcon({ path: Icons.STORE, iconSize: 16, color: Theme.TEXT_SUB })

      Column() {
        Text('浙江农林大学店')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
        Text('杭州市临安区武肃街 666 号 · 营业中 07:00-23:00')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 4 })
          .maxLines(2)
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFF9EC')
    .borderRadius(12)
    .margin({ top: topGap })
  }

  build() {
    Scroll() {
      Column() {
        this.header()

        Column() {
          Text('请选择取餐方式')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 20, bottom: 12 })

          this.entryCard('外送到家', '骑手送到你手上，约 30 分钟', '免配送费', Icons.DELIVERY, '#FFEDF0', 'DELIVERY', 0)
          this.entryCard('到店自取', '下单后凭取餐码到店取餐', '快', Icons.STORE, '#FFF6E0', 'PICKUP', 12)

          this.storeInfo(18)
        }
        .width('100%')
        .padding({ left: Theme.GAP + 4, right: Theme.GAP + 4, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
