import { Theme, Constants } from '../common/Constants';
import { User } from '../model/User';
import { UserApi } from '../api/UserApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 登录 / 注册页
 *
 * 演示环境把账号密码印在界面上，直接照抄就能登录，方便答辩时演示。
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
      CartViewModel.setCurrentUserId(user.id);
      await CartViewModel.refresh(user.id);
      this.toast(`${this.mode === 'LOGIN' ? '登录' : '注册'}成功，欢迎 ${user.nickname ?? user.username}`);
      this.getUIContext().getRouter().back();
    } catch (err) {
      this.toast(`${err}`);
    }
    this.submitting = false;
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
  }

  @Builder
  field(label: string, value: string, placeholder: string, secret: boolean, onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')

      TextInput({ placeholder: placeholder, text: value })
        .type(secret ? InputType.Password : InputType.Normal)
        .width('100%')
        .height(42)
        .fontSize(14)
        .backgroundColor('#F7F7F7')
        .borderRadius(8)
        .margin({ top: 6 })
        .onChange(onChange)
    }
    .width('100%')
    .margin({ top: 14 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        // 返回：矢量箭头（原来是文字字符 ‹）
        Row() {
          VectorIcon({ path: Icons.ARROW_BACK, iconSize: 18, color: Theme.TEXT })
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })

        Text(this.mode === 'LOGIN' ? '登录' : '注册')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('')
          .width(44)
      }
      .width('100%')
      .height(48)
      .backgroundColor(Theme.CARD)
      .alignItems(VerticalAlign.Center)

      Column() {
        Text('KFC 点餐')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY)
          .width('100%')

        Text('鸿蒙端演示工程 · 前后端联调')
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
          .margin({ top: 6 })

        this.field('账号', this.username, '请输入用户名', false, (v: string) => {
          this.username = v;
        })
        this.field('密码', this.password, '请输入密码', true, (v: string) => {
          this.password = v;
        })

        if (this.mode === 'REGISTER') {
          this.field('昵称', this.nickname, '选填', false, (v: string) => {
            this.nickname = v;
          })
          this.field('手机号', this.phone, '选填', false, (v: string) => {
            this.phone = v;
          })
        }

        Text(this.submitting ? '提交中…' : (this.mode === 'LOGIN' ? '登 录' : '注 册'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(44)
          .borderRadius(22)
          .backgroundColor(this.submitting ? '#D0D0D0' : Theme.PRIMARY)
          .margin({ top: 24 })
          .onClick(() => {
            if (!this.submitting) {
              this.submit();
            }
          })

        Text(this.mode === 'LOGIN' ? '没有账号？去注册' : '已有账号？去登录')
          .fontSize(13)
          .fontColor(Theme.PRIMARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 16 })
          .onClick(() => {
            this.mode = this.mode === 'LOGIN' ? 'REGISTER' : 'LOGIN';
          })

        Column() {
          Text('演示账号')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
          Text(`账号 ${Constants.DEMO_USERNAME}    密码 ${Constants.DEMO_PASSWORD}`)
            .fontSize(13)
            .fontColor(Theme.TEXT)
            .margin({ top: 4 })
          Text('点「我的 - 演示账号一键登录」也能直接进去')
            .fontSize(11)
            .fontColor(Theme.TEXT_HINT)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#FFF4E0')
        .borderRadius(8)
        .margin({ top: 30 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 24, right: 24, top: 40 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
