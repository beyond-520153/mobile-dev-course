import { Theme } from '../common/Constants';
import { Icons, VectorIcon } from './VectorIcon';

/**
 * 深色底部 tab（首页 / 百胜出品 / AI点餐 / 大神卡 / 会员中心）
 *
 * 入口页、WOW 会员中心、大神卡三页共用这一条，只有高亮项不同：
 * active 传 'home' | 'square' | 'ai' | 'card' | 'wow'。
 *
 * 中间「AI点餐」是凸起的红球（offset 上移 16vp），和官方一致；
 * 点击用 replaceUrl 而不是 pushUrl —— 底栏切页不该把路由堆起来。
 */
@Component
export struct EntryTabBar {

  /** 当前高亮项 */
  @Prop active: string = 'home';

  private tip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      console.warn('showToast failed: ' + JSON.stringify(e));
    }
  }

  private go(url: string, key: string): void {
    if (this.active === key) {
      return;
    }
    try {
      this.getUIContext().getRouter().replaceUrl({ url: url });
    } catch (e) {
      console.error('replaceUrl ' + url + ' failed: ' + JSON.stringify(e));
    }
  }

  build() {
    Row() {
      // 1. 首页（K 标）
      Column() {
        Text('K')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontStyle(FontStyle.Italic)
          .fontColor(Theme.PRIMARY)
        Text('首页')
          .fontSize(9.5)
          .fontWeight(this.active === 'home' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.active === 'home' ? '#FF5468' : '#EDEDED')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .height(50)
      .justifyContent(FlexAlign.End)
      .onClick(() => {
        this.go('pages/EntryPage', 'home');
      })

      // 2. 百胜出品（四宫格）
      Column() {
        Column() {
          Row() {
            Text('').width(6).height(6).backgroundColor('#FFFFFF')
            Text('').width(6).height(6).backgroundColor('#FFFFFF').margin({ left: 2 })
          }
          Row() {
            Text('').width(6).height(6).backgroundColor('#FFFFFF')
            Text('').width(6).height(6).backgroundColor('#FFFFFF').margin({ left: 2 })
          }
          .margin({ top: 2 })
        }
        Text('百胜出品')
          .fontSize(9.5)
          .fontWeight(this.active === 'square' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.active === 'square' ? '#FF5468' : '#EDEDED')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .height(50)
      .justifyContent(FlexAlign.End)
      .onClick(() => {
        this.tip('「百胜出品」功能正在开发中');
      })

      // 3. 中间凸起的 AI 点餐
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          // 外圈光晕（画在红球下面，只露出一圈）
          Circle()
            .width(64)
            .height(64)
            .fill('#33E4002B')
          Circle()
            .width(54)
            .height(54)
            .fill('#E4002B')
            .shadow({
              radius: 16,
              color: '#33000000',
              offsetX: 0,
              offsetY: 6
            })
          Text('K')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(64)
        .height(64)

        Text('AI点餐')
          .fontSize(9.5)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF5468')
          .margin({ top: 1 })
      }
      .layoutWeight(1)
      .offset({ x: 0, y: -18 })
      .onClick(() => {
        this.tip('「AI点餐」功能正在开发中');
      })

      // 4. 大神卡
      Column() {
        VectorIcon({
          path: Icons.CROWN,
          iconSize: 18,
          color: this.active === 'card' ? '#FF5468' : '#FFFFFF'
        })
        Text('大神卡')
          .fontSize(9.5)
          .fontWeight(this.active === 'card' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.active === 'card' ? '#FF5468' : '#EDEDED')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .height(50)
      .justifyContent(FlexAlign.End)
      .onClick(() => {
        // 大神卡页没有底栏（只有顶栏返回键），必须 push 才能退回来
        if (this.active !== 'card') {
          try {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/MemberCardPage' });
          } catch (e) {
            console.error('pushUrl MemberCardPage failed: ' + JSON.stringify(e));
          }
        }
      })

      // 5. WOW 会员中心
      Column() {
        Text('WOW')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontStyle(FontStyle.Italic)
          .fontColor('#FFFFFF')
        Text('会员中心')
          .fontSize(9.5)
          .fontWeight(this.active === 'wow' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.active === 'wow' ? '#FF5468' : '#EDEDED')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .height(50)
      .justifyContent(FlexAlign.End)
      .onClick(() => {
        this.go('pages/WOWMemberPage', 'wow');
      })
    }
    .width('100%')
    .height(60)
    .padding({ bottom: 5 })
    .alignItems(VerticalAlign.Bottom)
    .linearGradient({
      angle: 180,
      colors: [['#3C3C3C', 0.0], ['#1D1D1D', 1.0]]
    })
  }
}
