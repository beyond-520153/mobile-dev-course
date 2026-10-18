import { StoreInfo, Theme, pickupLabel } from '../common/Constants';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 选择餐厅 —— 复刻官方 store/packages/stores/pages/map/index
 *
 * 顶部导航（返回 / 选择餐厅 / 收起地图）→ 城市 + 搜索行 → 登录得 V金 提示
 * → 地图占位（150 高）→「附近餐厅 / 收藏&常去」页签 → 门店卡（名称 / 地址 / 时段 / 距离）
 * 门店固定为浙江农林大学店（真实门店，杭州临安武肃街 666 号）。
 */
@Entry
@Component
struct StorePage {

  @StorageLink('pickupType') pickupType: string = 'PICKUP';
  @StorageLink('userId') userId: number = 0;
  @State tabSel: number = 0;
  @State keyword: string = '';

  private notify(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 });
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
        this.notify('返回失败');
      }
    }
  }

  private startOrder(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/Index' });
    } catch (e) {
      this.notify('页面跳转失败');
    }
  }

  @Builder
  navBar() {
    Row() {
      Row() {
        VectorIcon({ path: Icons.ARROW_BACK, iconSize: 20, color: Theme.TEXT })
      }
      .width(40)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.back())

      Text('选择餐厅')
        .fontSize(16.6)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text('收起地图')
        .fontSize(12.5)
        .fontColor(Theme.TEXT_SUB)
        .width(64)
        .textAlign(TextAlign.End)
        .onClick(() => this.notify('地图已收起（演示占位）'))
    }
    .width('100%')
    .height(48)
    .padding({ left: 6, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: Theme.DIVIDER })
  }

  @Builder
  searchRow() {
    Row() {
      Row() {
        Text('杭州').fontSize(12.5).fontColor(Theme.TEXT)
        Text('▾').fontSize(9).fontColor(Theme.TEXT_HINT).margin({ left: 3 })
      }
      .margin({ right: 8 })

      Row() {
        VectorIcon({ path: Icons.SEARCH, iconSize: 13, color: '#B0B0B0' })
        TextInput({ placeholder: '请选择城市或打开定位', text: this.keyword })
          .placeholderColor('#B0B0B0')
          .fontSize(12.5)
          .fontColor(Theme.TEXT)
          .backgroundColor(Color.Transparent)
          .padding(0)
          .height(26)
          .layoutWeight(1)
          .margin({ left: 6 })
          .onChange((v: string) => {
            this.keyword = v;
          })
      }
      .height(31)
      .padding({ left: 9, right: 9 })
      .backgroundColor('#F5F5F5')
      .borderRadius(5)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 12.5, right: 12.5, top: 9, bottom: 9 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  loginTip() {
    Row() {
      Text('i')
        .fontSize(8)
        .fontColor('#C9C9C9')
        .width(11)
        .height(11)
        .borderRadius(6)
        .border({ width: 0.5, color: '#C9C9C9' })
        .textAlign(TextAlign.Center)
      Text('登录后点餐可获赠V金哦~')
        .fontSize(11.4)
        .fontColor(Theme.TEXT_SUB)
        .margin({ left: 5 })
        .layoutWeight(1)
      Text(this.userId > 0 ? '已登录' : '立即登录')
        .fontSize(11.4)
        .fontColor('#FFFFFF')
        .height(20)
        .padding({ left: 11, right: 11 })
        .borderRadius(10)
        .backgroundColor(Theme.PRIMARY)
        .onClick(() => {
          if (this.userId <= 0) {
            try {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
            } catch (e) {
              this.notify('页面跳转失败');
            }
          }
        })
    }
    .width('100%')
    .padding({ left: 12.5, right: 12.5, bottom: 9 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  mapArea() {
    // 官方 map.png 是极小的切片图，拉伸会糊；这里画矢量风底图（浅灰网格 + 主干道 + 红色定位针）
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#EEF1EC')

      // 横竖两条主干道
      Column()
        .width('100%')
        .height(11)
        .backgroundColor('#FFFFFF')
        .position({ x: 0, y: 74 })

      Column()
        .width(11)
        .height('100%')
        .backgroundColor('#FFFFFF')
        .position({ x: 170, y: 0 })

      // 街区
      Column().width(96).height(42).borderRadius(3).backgroundColor('#E3E8E0')
        .position({ x: 18, y: 16 })
      Column().width(132).height(48).borderRadius(3).backgroundColor('#E3E8E0')
        .position({ x: 214, y: 14 })
      Column().width(112).height(36).borderRadius(3).backgroundColor('#E3E8E0')
        .position({ x: 26, y: 100 })
      Column().width(104).height(32).borderRadius(3).backgroundColor('#E3E8E0')
        .position({ x: 238, y: 104 })

      // 定位针（红色矢量）
      VectorIcon({ path: Icons.LOCATION, iconSize: 28, color: Theme.PRIMARY })
        .position({ x: 181, y: 60 })

      // 重新定位按钮
      Stack() {
        VectorIcon({ path: Icons.LOCATION, iconSize: 15, color: Theme.TEXT_SUB })
      }
      .width(30)
      .height(30)
      .borderRadius(15)
      .backgroundColor('#FFFFFF')
      .position({ x: 344, y: 106 })
      .onClick(() => this.notify('已按定位刷新附近餐厅'))
    }
    .width('100%')
    .height(150)
    .backgroundColor('#EEF1EC')
    .clip(true)
  }

  @Builder
  tabs() {
    Row() {
      this.tabItem(0, '附近餐厅')
      this.tabItem(1, '收藏&常去')
    }
    .width('100%')
    .padding({ left: 12.5, right: 12.5, top: 12, bottom: 6 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  tabItem(idx: number, label: string) {
    Column() {
      Text(label)
        .fontSize(14.6)
        .fontWeight(this.tabSel === idx ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.tabSel === idx ? Theme.TEXT : Theme.TEXT_HINT)
      Row()
        .width(16)
        .height(2.6)
        .borderRadius(2)
        .backgroundColor(this.tabSel === idx ? Theme.PRIMARY : Color.Transparent)
        .margin({ top: 6 })
    }
    .margin({ right: 22 })
    .onClick(() => {
      this.tabSel = idx;
    })
  }

  @Builder
  storeCard() {
    Row() {
      Column() {
        Row() {
          Text(StoreInfo.SHORT)
            .fontSize(14.6)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
          Text('营业中')
            .fontSize(9.4)
            .fontColor(Theme.PRIMARY)
            .border({ width: 0.5, color: Theme.PRIMARY })
            .borderRadius(2)
            .padding({ left: 3, right: 3 })
            .margin({ left: 6 })
        }
        .alignItems(VerticalAlign.Center)

        Text(StoreInfo.ADDR)
          .fontSize(11.4)
          .fontColor(Theme.TEXT_HINT)
          .lineHeight(16)
          .margin({ top: 5 })
          .maxLines(2)

        Row() {
          Text(StoreInfo.HOURS).fontSize(11.4).fontColor(Theme.TEXT_SUB).margin({ right: 10 })
          Text('到店自取').fontSize(11.4).fontColor(Theme.TEXT_SUB).margin({ right: 10 })
          Text('外送到家').fontSize(11.4).fontColor(Theme.TEXT_SUB)
        }
        .margin({ top: 5 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(StoreInfo.DIST)
        .fontSize(11.4)
        .fontColor(Theme.TEXT_HINT)
        .margin({ left: 8, top: 3 })

      Text('已选')
        .fontSize(12.5)
        .fontColor('#FFFFFF')
        .height(28)
        .padding({ left: 14, right: 14 })
        .borderRadius(14)
        .backgroundColor(Theme.PRIMARY)
        .margin({ left: 8 })
        .onClick(() => this.startOrder())
    }
    .width('100%')
    .padding({ left: 12.5, right: 12.5, top: 13, bottom: 13 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: '#F2F2F2' })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.navBar()
      this.searchRow()
      this.loginTip()
      this.mapArea()
      this.tabs()

      Scroll() {
        Column() {
          if (this.tabSel === 0) {
            this.storeCard()
            Text('已按定位（30.258056, 119.724181）排序，仅显示附近可点餐餐厅')
              .fontSize(11.4)
              .fontColor('#B0B0B0')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 26, bottom: 26 })
          } else {
            Column() {
              VectorIcon({ path: Icons.STAR, iconSize: 40, color: '#DDDDDD' })
              Text('还没有收藏的门店').fontSize(12.5).fontColor(Theme.TEXT_HINT).margin({ top: 8 })
            }
            .width('100%')
            .padding({ top: 50, bottom: 50 })
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
