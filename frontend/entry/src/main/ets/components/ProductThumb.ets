import { Theme } from '../common/Constants';

/**
 * 餐品缩略图
 *
 * 联调期后端 image 字段放的是 emoji（如 🍔），这里按文字渲染在暖色底块上；
 * 以后换成真实图片 URL（以 http 开头）会自动切到 Image 渲染，页面代码不用改。
 */
@Component
export struct ProductThumb {

  @Prop image: string = '';
  /** 注意：不能叫 size —— 会与 CustomComponent 基类的 size() 属性方法冲突 */
  @Prop thumbSize: number = 78;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.image.startsWith('http')) {
        Image(this.image)
          .width(this.thumbSize)
          .height(this.thumbSize)
          .borderRadius(this.thumbSize * 0.2)
          .objectFit(ImageFit.Cover)
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
