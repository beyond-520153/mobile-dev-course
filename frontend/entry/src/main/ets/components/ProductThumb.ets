import { Theme, Constants } from '../common/Constants';

/**
 * 餐品缩略图
 *
 * 后端 image 字段现在存的是官方图相对路径（如 /images/products/100127264.gif），
 * 由后端静态资源提供，这里补上服务端地址；若给的是完整 http 地址则原样使用。
 * 两者都不是时退化为文字块（兼容历史 emoji 数据）。
 */
@Component
export struct ProductThumb {

  @Prop image: string = '';
  /** 注意：不能叫 size —— 会与 CustomComponent 基类的 size() 属性方法冲突 */
  @Prop thumbSize: number = 78;

  private resolveSrc(): string {
    if (this.image.startsWith('http')) {
      return this.image;
    }
    if (this.image.startsWith('/')) {
      return Constants.BASE_URL + this.image;
    }
    return '';
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.resolveSrc().length > 0) {
        Image(this.resolveSrc())
          .width(this.thumbSize)
          .height(this.thumbSize)
          .borderRadius(this.thumbSize * 0.2)
          .objectFit(ImageFit.Cover)
          .backgroundColor(Theme.THUMB_BG)
      } else {
        Text(this.image.length > 0 ? this.image : '🍔')
          .fontSize(this.thumbSize * 0.46)
          .textAlign(TextAlign.Center)
          .width(this.thumbSize)
          .height(this.thumbSize)
          .borderRadius(this.thumbSize * 0.2)
          .backgroundColor(Theme.THUMB_BG)
      }
    }
    .width(this.thumbSize)
    .height(this.thumbSize)
  }
}
