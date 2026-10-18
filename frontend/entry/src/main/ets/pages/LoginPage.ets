import { Constants, Theme } from '../common/Constants';
import { User } from '../model/User';
import { UserApi } from '../api/UserApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 登录 / 注册 —— 对齐官方「会员登录」页
 *
 * 官方是纯白底 + 红色 KFC 标识 + 下划线输入 + 红色胶囊按钮，
 * 没有卡片和色块。这里照此重排，演示账号直接印在按钮下方。
 */
@Entry
@Component
struct LoginPage {

  @State username: string = Constants.DEMO_USERNAME;
  @State password: string = Constants.DEMO_PASSWORD;
  @State nickname: string = '';
  @State phone: string = '';
  @State mode: string = 'LOGIN';
  @State submitting: boolean = false;

  private async submit(): Promise<void> {
    if (this.username.length === 0 || this.password.length === 0) {
      this.toast('账号和密码都要填');
      return;
    }
    this.submitting = true;
    try {
      let user: User;
      if (this.mode === 'LOGIN') {
        user = await UserApi.login(this.username, this.password);
      } else {
        user = await UserApi.register(this.username, this.password, this.phone, this.nickname);
      }
      const showName: string = (user.nickname !== undefined && user.nickname.length > 0)
        ? user.nickname : user.username;
      CartViewModel.setCurrentUser(user.id, showName);
      await CartViewModel.refresh(user.id);
      this.toast(`${this.mode === 'LOGIN' ? '登录' : '注册'}成功，欢迎 ${showName}`);
      this.back();
    } catch (err) {
      this.toast(`${err}`);
    }
    this.submitting = false;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1600 });
    } catch (e) {
      // 忽略
    }
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (e) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/EntryPage' });
      } catch (e2) {
        this.toast('返回失败');
      }
    }
  }

  /** 官方输入框只有一条底边，没有灰底圆角 */
  @Builder
  field(placeholder: string, value: string, secret: boolean, onChange: (v: string) => void) {
    Column() {
      TextInput({ placeholder: placeholder, text: value })
        .type(secret ? InputType.Password : InputType.Normal)
        .width('100%')
        .height(46)
        .padding(0)
        .fontSize(14.6)
        .fontColor(Theme.TEXT)
        .placeholderColor('#B0B0B0')
        .backgroundColor(Color.Transparent)
        .onChange(onChange)
      Divider().color('#EEEEEE')
    }
    .width('100%')
    .margin({ top: 6 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  navBar() {
    Row() {
      Row() {
        VectorIcon({ path: Icons.ARROW_BACK, iconSize: 20, color: Theme.TEXT })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.back())

      Text(this.mode === 'LOGIN' ? '登录' : '注册')
        .fontSize(16.6)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text(this.mode === 'LOGIN' ? '注册' : '去登录')
        .fontSize(12.5)
        .fontColor(Theme.TEXT_SUB)
        .width(44)
        .textAlign(TextAlign.End)
        .onClick(() => {
          this.mode = this.mode === 'LOGIN' ? 'REGISTER' : 'LOGIN';
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.navBar()

      Scroll() {
        Column() {
          Text('KFC')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontStyle(FontStyle.Italic)
            .fontColor(Theme.PRIMARY)
            .width('100%')
            .margin({ top: 36 })

          Text(this.mode === 'LOGIN' ? '登录后可点餐、查看订单' : '注册成为会员，享专属优惠')
            .fontSize(12.5)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
            .margin({ top: 8 })

          this.field('请输入账号', this.username, false, (v: string) => {
            this.username = v;
          })
          this.field('请输入密码', this.password, true, (v: string) => {
            this.password = v;
          })

          if (this.mode === 'REGISTER') {
            this.field('请输入昵称（选填）', this.nickname, false, (v: string) => {
              this.nickname = v;
            })
            this.field('请输入手机号（选填）', this.phone, false, (v: string) => {
              this.phone = v;
            })
          }

          Text(this.submitting ? '提交中…' : (this.mode === 'LOGIN' ? '登录' : '注册'))
            .fontSize(14.6)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(44)
            .borderRadius(22)
            .backgroundColor(this.submitting ? '#D0D0D0' : Theme.PRIMARY)
            .margin({ top: 28 })
            .onClick(() => {
              if (!this.submitting) {
                this.submit();
              }
            })

          Text('登录即表示同意《隐私政策》与《用户协议》')
            .fontSize(10.4)
            .fontColor(Theme.TEXT_HINT)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 14 })

          Text(`使用演示账号 ${Constants.DEMO_USERNAME} / ${Constants.DEMO_PASSWORD}`)
            .fontSize(11.4)
            .fontColor(Theme.PRIMARY)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 10 })
        }
        .width('100%')
        .padding({ left: 25, right: 25 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
