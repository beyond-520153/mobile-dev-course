import { Theme } from '../common/Constants';
import { Address } from '../model/Address';
import { AddressApi, AddressBody } from '../api/AddressApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 收货地址 —— 对齐官方「我的地址」页
 *
 * 顶部白色导航（返回 / 收货地址 / 管理）
 * 地址白卡：收货人 + 手机号 + 默认标 + 详细地址 + 底部「设为默认 / 删除」
 * 底部固定一条红色胶囊「新增收货地址」
 *
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
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
    } catch (e) {
      // 忽略
    }
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (e) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/MinePage' });
      } catch (e2) {
        this.toast('返回失败');
      }
    }
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

      Text('收货地址')
        .fontSize(16.6)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text(this.showForm ? '取消' : '')
        .fontSize(12.5)
        .fontColor(Theme.TEXT_SUB)
        .width(44)
        .textAlign(TextAlign.End)
        .onClick(() => {
          if (this.showForm) {
            this.showForm = false;
          }
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  field(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(Theme.TEXT)
        .width(66)
      TextInput({ placeholder: placeholder, text: value })
        .layoutWeight(1)
        .height(40)
        .padding(0)
        .fontSize(13)
        .placeholderColor('#B0B0B0')
        .backgroundColor(Color.Transparent)
        .onChange(onChange)
      VectorIcon({ path: Icons.CHEVRON, iconSize: 13, color: '#E0E0E0' })
    }
    .width('100%')
    .height(46)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  form() {
    Column() {
      Text('新增收货地址')
        .fontSize(14.6)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .width('100%')
        .margin({ bottom: 4 })

      this.field('收货人', this.receiver, '请输入收货人姓名', (v: string) => {
        this.receiver = v;
      })
      Divider().color('#F5F5F5')
      this.field('手机号', this.phone, '请输入手机号', (v: string) => {
        this.phone = v;
      })
      Divider().color('#F5F5F5')
      this.field('省份', this.province, '省', (v: string) => {
        this.province = v;
      })
      Divider().color('#F5F5F5')
      this.field('城市', this.city, '市', (v: string) => {
        this.city = v;
      })
      Divider().color('#F5F5F5')
      this.field('区县', this.district, '区/县', (v: string) => {
        this.district = v;
      })
      Divider().color('#F5F5F5')
      this.field('详细地址', this.detail, '街道、门牌号、楼层', (v: string) => {
        this.detail = v;
      })
      Divider().color('#F5F5F5')

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
      .height(48)
      .alignItems(VerticalAlign.Center)

      Text(this.submitting ? '保存中…' : '保存地址')
        .fontSize(14.6)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(42)
        .borderRadius(21)
        .backgroundColor(this.submitting ? '#D0D0D0' : Theme.PRIMARY)
        .margin({ top: 10, bottom: 4 })
        .onClick(() => {
          if (!this.submitting) {
            this.create();
          }
        })
    }
    .width('100%')
    .padding({ left: 12.5, right: 12.5, top: 13 })
    .backgroundColor('#FFFFFF')
    .borderRadius(Theme.RADIUS)
    .margin({ top: 9 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  addressCard(address: Address) {
    Column() {
      Row() {
        Text(address.receiver)
          .fontSize(14.6)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
        Text(address.phone)
          .fontSize(12.5)
          .fontColor(Theme.TEXT_SUB)
          .margin({ left: 8 })
        if (address.isDefault) {
          Text('默认')
            .fontSize(9.8)
            .fontColor(Theme.PRIMARY)
            .border({ width: 0.5, color: Theme.PRIMARY })
            .borderRadius(2)
            .padding({ left: 3, right: 3, top: 1, bottom: 1 })
            .margin({ left: 6 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(address.fullAddress)
        .fontSize(12.5)
        .fontColor(Theme.TEXT_SUB)
        .lineHeight(18)
        .margin({ top: 6 })
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Divider().color('#F5F5F5').margin({ top: 10, bottom: 2 })

      Row() {
        if (!address.isDefault) {
          Row() {
            VectorIcon({ path: Icons.STAR, iconSize: 11, color: '#C9C9C9' })
            Text('设为默认')
              .fontSize(11.4)
              .fontColor(Theme.TEXT_SUB)
              .margin({ left: 3 })
          }
          .onClick(() => this.setDefault(address))
        }
        Blank()
        Row() {
          VectorIcon({ path: Icons.CLOSE, iconSize: 11, color: '#C9C9C9' })
          Text('删除')
            .fontSize(11.4)
            .fontColor(Theme.TEXT_SUB)
            .margin({ left: 3 })
        }
        .onClick(() => this.remove(address))
      }
      .width('100%')
      .height(40)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 12.5, right: 12.5, top: 13, bottom: 2 })
    .backgroundColor('#FFFFFF')
    .borderRadius(Theme.RADIUS)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.navBar()

      if (this.loading) {
        Column() {
          LoadingProgress().width(34).height(34).color(Theme.PRIMARY)
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
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 40 })
            } else if (this.addresses.length === 0) {
              Column() {
                VectorIcon({ path: Icons.LOCATION, iconSize: 46, color: '#D8D8D8' })
                Text('还没有收货地址')
                  .fontSize(13.5)
                  .fontColor(Theme.TEXT_SUB)
                  .margin({ top: 12 })
              }
              .width('100%')
              .padding({ top: 70, bottom: 60 })
              .justifyContent(FlexAlign.Center)
            } else {
              Column() {
                ForEach(this.addresses, (address: Address) => {
                  Column() {
                    this.addressCard(address)
                  }
                  .margin({ top: 9 })
                }, (address: Address) => `${address.id}-${address.isDefault}`)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 8, right: 8, bottom: 16 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(Theme.BG)
      }

      // 底部固定新增按钮（官方样式：整条红色胶囊）
      Row() {
        Text('新增收货地址')
          .fontSize(14.6)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(42)
          .borderRadius(21)
          .backgroundColor(Theme.PRIMARY)
          .onClick(() => {
            this.showForm = true;
          })
      }
      .width('100%')
      .padding({ left: 12.5, right: 12.5, top: 8, bottom: 12 })
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 0.5 }, color: '#F2F2F2' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
