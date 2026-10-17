import { Theme } from '../common/Constants';
import { Address } from '../model/Address';
import { AddressApi, AddressBody } from '../api/AddressApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 收货地址页
 *
 * 列表 + 内嵌新增表单（不弹窗，少一层交互，也避免弹窗 API 的版本差异）。
 * 「设为默认」在后端会把该用户其它地址的默认标记清掉，前端只负责调接口。
 */
@Entry
@Component
struct AddressPage {

  @State addresses: Address[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State showForm: boolean = false;
  @State submitting: boolean = false;

  // 新增表单字段
  @State receiver: string = '';
  @State phone: string = '';
  @State province: string = '浙江省';
  @State city: string = '杭州市';
  @State district: string = '临安区';
  @State detail: string = '';
  @State asDefault: boolean = true;

  @StorageLink('userId') userId: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const uid = CartViewModel.currentUserId();
    if (uid <= 0) {
      this.errorMsg = '请先登录';
      this.loading = false;
      return;
    }
    this.loading = true;
    try {
      this.addresses = await AddressApi.listByUser(uid);
      this.errorMsg = '';
    } catch (err) {
      this.errorMsg = `地址加载失败：${err}`;
    }
    this.loading = false;
  }

  private async create(): Promise<void> {
    const uid = CartViewModel.currentUserId();
    if (this.receiver.length === 0 || this.phone.length === 0 || this.detail.length === 0) {
      this.toast('收货人、手机号、详细地址都要填');
      return;
    }
    this.submitting = true;
    try {
      const body: AddressBody = {
        userId: uid,
        receiver: this.receiver,
        phone: this.phone,
        province: this.province,
        city: this.city,
        district: this.district,
        detail: this.detail,
        isDefault: this.asDefault
      };
      await AddressApi.create(body);
      this.showForm = false;
      this.detail = '';
      this.receiver = '';
      this.phone = '';
      await this.load();
      this.toast('地址已保存');
    } catch (err) {
      this.toast(`${err}`);
    }
    this.submitting = false;
  }

  private async setDefault(address: Address): Promise<void> {
    try {
      const body: AddressBody = {
        userId: address.userId,
        receiver: address.receiver,
        phone: address.phone,
        province: address.province ?? '',
        city: address.city ?? '',
        district: address.district ?? '',
        detail: address.detail,
        isDefault: true
      };
      await AddressApi.update(address.id, body);
      await this.load();
      this.toast('已设为默认地址');
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private async remove(address: Address): Promise<void> {
    try {
      await AddressApi.remove(address.id, address.userId);
      await this.load();
      this.toast('已删除');
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
  }

  @Builder
  navBar() {
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

      Text('收货地址')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text(this.showForm ? '取消' : '新增')
        .fontSize(13)
        .fontColor(Theme.PRIMARY)
        .width(44)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.showForm = !this.showForm;
        })
    }
    .width('100%')
    .height(48)
    .backgroundColor(Theme.CARD)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  field(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(Theme.TEXT_SUB)
        .width(64)
      TextInput({ placeholder: placeholder, text: value })
        .layoutWeight(1)
        .height(38)
        .fontSize(13)
        .backgroundColor('#F7F7F7')
        .borderRadius(8)
        .onChange(onChange)
    }
    .width('100%')
    .margin({ top: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  form() {
    Column() {
      Row() {
        Text('新增收货地址')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')

      this.field('收货人', this.receiver, '请输入收货人', (v: string) => {
        this.receiver = v;
      })
      this.field('手机号', this.phone, '请输入手机号', (v: string) => {
        this.phone = v;
      })
      this.field('省份', this.province, '省', (v: string) => {
        this.province = v;
      })
      this.field('城市', this.city, '市', (v: string) => {
        this.city = v;
      })
      this.field('区县', this.district, '区/县', (v: string) => {
        this.district = v;
      })
      this.field('详细地址', this.detail, '街道、门牌号', (v: string) => {
        this.detail = v;
      })

      Row() {
        Text('设为默认地址')
          .fontSize(13)
          .fontColor(Theme.TEXT)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.asDefault })
          .selectedColor(Theme.PRIMARY)
          .onChange((isOn: boolean) => {
            this.asDefault = isOn;
          })
      }
      .width('100%')
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Center)

      Text(this.submitting ? '保存中…' : '保存地址')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(40)
        .borderRadius(20)
        .backgroundColor(this.submitting ? '#D0D0D0' : Theme.PRIMARY)
        .margin({ top: 14 })
        .onClick(() => {
          if (!this.submitting) {
            this.create();
          }
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.CARD)
    .borderRadius(10)
    .margin({ top: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  addressCard(address: Address) {
    Column() {
      Row() {
        Text(address.receiver)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
        Text(address.phone)
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
          .margin({ left: 10 })
        Blank()
        if (address.isDefault) {
          Text('默认')
            .fontSize(10)
            .fontColor(Theme.PRIMARY)
            .border({ width: 1, color: Theme.PRIMARY })
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(address.fullAddress)
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .margin({ top: 6 })
        .width('100%')

      Row() {
        Blank()
        if (!address.isDefault) {
          Text('设为默认')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(28)
            .borderRadius(14)
            .border({ width: 1, color: Theme.DIVIDER })
            .onClick(() => {
              this.setDefault(address);
            })
        }
        Text('删除')
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
          .textAlign(TextAlign.Center)
          .width(56)
          .height(28)
          .borderRadius(14)
          .border({ width: 1, color: Theme.DIVIDER })
          .margin({ left: 8 })
          .onClick(() => {
            this.remove(address);
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.CARD)
    .borderRadius(10)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.navBar()

      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color(Theme.PRIMARY)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.showForm) {
              this.form()
            }

            if (this.errorMsg.length > 0) {
              Text(this.errorMsg)
                .fontSize(13)
                .fontColor(Theme.TEXT_SUB)
                .margin({ top: 20 })
            } else if (this.addresses.length === 0) {
              Column() {
                VectorIcon({ path: Icons.LOCATION, iconSize: 48, color: '#D8D8D8' })
                Text('还没有收货地址')
                  .fontSize(13)
                  .fontColor(Theme.TEXT_SUB)
                  .margin({ top: 10 })
              }
              .width('100%')
              .margin({ top: 60 })
            } else {
              ForEach(this.addresses, (address: Address) => {
                Column() {
                  this.addressCard(address)
                }
                .margin({ top: 10 })
              }, (address: Address) => `${address.id}-${address.isDefault}`)
            }
          }
          .width('100%')
          .padding({ left: Theme.GAP, right: Theme.GAP, bottom: 20 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
