import { Theme } from '../common/Constants';
import { Product } from '../model/Product';
import { ProductThumb } from './ProductThumb';

/**
 * 餐品卡片 —— 点餐列表的一行
 *
 * 版式参照肯德基小程序：左图右文，名称加粗、描述灰色、价格红色，
 * 右下角是加购按钮；库存为 0 时按钮置灰并打「售罄」角标。
 */
@Component
export struct ProductCard {

  @Prop product: Product = {
    id: 0,
    categoryId: 0,
    name: '',
    price: 0,
    stock: 0,
    sortOrder: 0,
    status: 1
  };

  /** 点「+」时回调给页面，由页面调加购接口 */
  onAdd: (product: Product) => void = () => {
  };

  /** 有折扣时才画划线原价，还原官方菜单的「原价 → 现价」 */
  private showOrigin(): boolean {
    const o: number | undefined = this.product.originPrice;
    return o !== undefined && o > this.product.price;
  }

  /** 会员价标签文案，空串表示当前用户没有可享的会员价 */
  private memberLabel(): string {
    const text: string | undefined = this.product.memberPriceText;
    return text === undefined ? '' : text;
  }

  build() {
    Row() {
      ProductThumb({ image: this.product.image ?? '', thumbSize: 78 })

      Column() {
        Text(this.product.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.product.description ?? '')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .width('100%')

        Row() {
          if (this.showOrigin()) {
            Text(`¥${this.product.originPrice}`)
              .fontSize(11)
              .fontColor(Theme.TEXT_SUB)
              .decoration({ type: TextDecorationType.LineThrough, color: Theme.TEXT_SUB })
              .margin({ right: 4 })
          }

          Text('¥')
            .fontSize(11)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)

          Text(`${this.product.price}`)
            .fontSize(17)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)

          // 登录且持卡时后端才会给这个文案，未登录不显示任何「专属价」痕迹
          if (this.memberLabel() !== '') {
            Text(this.memberLabel())
              .fontSize(9)
              .fontColor(Theme.PRIMARY)
              .backgroundColor('#FFF4E0')
              .borderRadius(3)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .margin({ left: 5 })
              .maxLines(1)
          }

          Blank()

          Text('+')
            .fontSize(18)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
            .width(26)
            .height(26)
            .textAlign(TextAlign.Center)
            .borderRadius(13)
            .backgroundColor(this.product.stock > 0 ? Theme.PRIMARY : '#D0D0D0')
            .onClick(() => {
              if (this.product.stock > 0) {
                this.onAdd(this.product);
              }
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .height(78)
      .margin({ left: 10 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: Theme.GAP, right: Theme.GAP, top: 12, bottom: 12 })
    .backgroundColor(Theme.CARD)
    .alignItems(VerticalAlign.Top)
  }
}
