import { Constants, StoreInfo, Theme, pickupLabel } from '../common/Constants';
import { Icons, VectorIcon } from '../components/VectorIcon';
import { ProductApi } from '../api/ProductApi';
import { CartApi, CartAddBody } from '../api/CartApi';
import { CartSummary } from '../model/ApiResult';
import { Category } from '../model/Category';
import { Product } from '../model/Product';

/**
 * 点餐页 —— 复刻肯德基手机端「到店自取」点餐界面
 *
 * 结构：顶部白色头（返回 + 门店名 + 切换 + 三个取餐方式 + 搜索）
 *      → 左侧分类栏 76 宽 / 右侧两列商品卡（官方 productItem：白底、1px #E6E6E6 边框、
 *        圆角 8、红字价格、右下角红色加号块）
 *      → 底部购物车条（红色圆形图标 + 合计 + 去结算）
 *
 * 取餐方式只影响文案与 AppStorage，不参与下单业务（Order.pickupType 仍写 PICKUP）。
 */
@Entry
@Component
struct Index {

  @StorageLink('pickupType') pickupType: string = 'PICKUP';
  @StorageLink('userId') userId: number = 0;
  @StorageLink('cartCount') cartCount: number = 0;
  @StorageLink('cartAmount') cartAmount: number = 0;
  @State categories: Category[] = [];
  @State products: Product[] = [];
  @State activeCatId: number = 0;
  @State keyword: string = '';
  @State searchResult: Product[] = [];
  @State searching: boolean = false;
  @State loading: boolean = true;
  @State errMsg: string = '';

  private base: string = Constants.BASE_URL;
  private searchTimer: number = -1;

  aboutToAppear(): void {
    const id = AppStorage.get<number>('userId');
    if (id !== undefined && id > 0) {
      this.userId = id;
    }
    this.loadAll();
  }

  aboutToDisappear(): void {
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
  }

  private notify(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 });
    } catch (e) {
      // 忽略
    }
  }

  private go(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (e) {
      this.notify('页面跳转失败');
    }
  }

  private goHome(): void {
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

  private async loadAll(): Promise<void> {
    this.loading = true;
    try {
      const cats = await ProductApi.listCategories();
      this.categories = cats;
      const list = await ProductApi.list();
      this.products = list.filter((p: Product) => p.status !== 0);
      if (this.categories.length > 0) {
        this.activeCatId = this.categories[0].id;
      }
      this.errMsg = '';
    } catch (e) {
      this.errMsg = '菜单加载失败，请检查后端是否启动';
    }
    this.loading = false;
    this.refreshCart();
  }

  private async refreshCart(): Promise<void> {
    if (this.userId <= 0) {
      this.cartCount = 0;
      this.cartAmount = 0;
      return;
    }
    try {
      const s: CartSummary = await CartApi.summary(this.userId);
      this.cartCount = s.count;
      this.cartAmount = s.amount;
    } catch (e) {
      // 金额拿不到不影响浏览
    }
  }

  /** 当前右侧要展示的商品 */
  private visibleProducts(): Product[] {
    if (this.searching) {
      return this.searchResult;
    }
    return this.products.filter((p: Product) => p.categoryId === this.activeCatId);
  }

  private activeCatName(): string {
    for (let i = 0; i < this.categories.length; i++) {
      if (this.categories[i].id === this.activeCatId) {
        return this.categories[i].name;
      }
    }
    return '全部餐品';
  }

  private onSearchChange(val: string): void {
    this.keyword = val;
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    if (val.length === 0) {
      this.searching = false;
      this.searchResult = [];
      return;
    }
    this.searchTimer = setTimeout(() => {
      this.doSearch(val);
    }, 300);
  }

  private async doSearch(kw: string): Promise<void> {
    if (kw.length === 0) {
      this.searching = false;
      this.searchResult = [];
      return;
    }
    try {
      const list = await ProductApi.search(kw);
      this.searchResult = list.filter((p: Product) => p.status !== 0);
      this.searching = true;
    } catch (e) {
      this.searchResult = [];
      this.searching = true;
      this.notify('搜索失败');
    }
  }

  private async addToCart(p: Product): Promise<void> {
    if (this.userId <= 0) {
      this.notify('请先登录');
      this.go('pages/LoginPage');
      return;
    }
    if (p.stock !== undefined && p.stock <= 0) {
      this.notify('该餐品已售罄');
      return;
    }
    try {
      const body: CartAddBody = { userId: this.userId, productId: p.id, quantity: 1 };
      await CartApi.add(body);
      await this.refreshCart();
      this.notify('已加入购物车');
    } catch (e) {
      this.notify('加入购物车失败');
    }
  }

  private money(v: number): string {
    return v.toFixed(2);
  }

  @Builder
  headBar() {
    Column() {
      Row() {
        Row() {
          VectorIcon({ path: Icons.ARROW_BACK, iconSize: 19, color: Theme.TEXT })
        }
        .width(26)
        .height(26)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 6 })
        .onClick(() => this.goHome())

        Text(StoreInfo.NAME)
          .fontSize(14.6)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text('切换')
          .fontSize(11.4)
          .fontColor(Theme.TEXT_SUB)
          .height(20)
          .padding({ left: 7, right: 7 })
          .border({ width: 0.5, color: Theme.DIVIDER })
          .borderRadius(10)
          .margin({ left: 6 })
          .onClick(() => this.go('pages/StorePage'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        this.pickTab('PICKUP', '到店自取')
        this.pickTab('DELIVERY', '外送到家')
        this.pickTab('DRIVE', '开车速取')

        Row() {
          VectorIcon({ path: Icons.SEARCH, iconSize: 12, color: '#B0B0B0' })
          TextInput({ placeholder: '搜索餐品', text: this.keyword })
            .placeholderColor('#B0B0B0')
            .fontSize(11.4)
            .fontColor(Theme.TEXT)
            .backgroundColor(Color.Transparent)
            .padding(0)
            .height(24)
            .layoutWeight(1)
            .onChange((v: string) => this.onSearchChange(v))
        }
        .height(26)
        .padding({ left: 9, right: 9 })
        .backgroundColor('#F5F5F5')
        .borderRadius(14)
        .margin({ left: 8 })
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 7 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 12.5, right: 12.5, top: 6, bottom: 9 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: '#F2F2F2' })
  }

  @Builder
  pickTab(type: string, label: string) {
    Column() {
      Text(label)
        .fontSize(13.5)
        .fontWeight(this.pickupType === type ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.pickupType === type ? Theme.TEXT : Theme.TEXT_HINT)
      Row()
        .width(14)
        .height(2.4)
        .borderRadius(2)
        .backgroundColor(this.pickupType === type ? Theme.PRIMARY : Color.Transparent)
        .margin({ top: 4 })
    }
    .margin({ right: 14 })
    .onClick(() => {
      this.pickupType = type;
    })
  }

  @Builder
  railItem(c: Category) {
    Column() {
      Text(c.name)
        .fontSize(11.4)
        .fontWeight(this.activeCatId === c.id && !this.searching ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.activeCatId === c.id && !this.searching ? Theme.PRIMARY : Theme.TEXT)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .padding({ left: 2, right: 2 })
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.activeCatId === c.id && !this.searching ? '#FFFFFF' : '#F7F7F7')
    .onClick(() => {
      this.activeCatId = c.id;
      this.keyword = '';
      this.searching = false;
      this.searchResult = [];
    })
  }

  @Builder
  productCard(p: Product) {
    Column() {
      Row() {
        if (p.image !== undefined && p.image.length > 0) {
          Image(this.base + p.image).width('100%').height(82).objectFit(ImageFit.Contain)
        } else {
          Row().width('100%').height(82).backgroundColor(Theme.THUMB_BG)
        }
      }
      .width('100%')
      .height(82)
      .justifyContent(FlexAlign.Center)

      Text(p.name)
        .fontSize(13)
        .fontColor(Theme.TEXT)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .height(33)
        .margin({ top: 6 })
        .alignSelf(ItemAlign.Start)

      if (p.description !== undefined && p.description.length > 0) {
        Text(p.description)
          .fontSize(9)
          .fontColor('#403C33')
          .backgroundColor(Theme.ACCENT)
          .borderRadius(4)
          .height(14)
          .padding({ left: 4, right: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .alignSelf(ItemAlign.Start)
      }

      Row() {
        Row() {
          Text('¥').fontSize(9.4).fontColor(Theme.PRIMARY)
          Text(this.money(p.price)).fontSize(13.6).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
          if (p.originPrice !== undefined && p.originPrice > p.price) {
            Text('¥' + this.money(p.originPrice))
              .fontSize(9.2)
              .fontColor('#B0B0B0')
              .decoration({ type: TextDecorationType.LineThrough, color: '#B0B0B0' })
              .margin({ left: 3 })
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Bottom)

        Row() {
          VectorIcon({ path: Icons.PLUS, iconSize: 11, color: '#FFFFFF' })
        }
        .width(23)
        .height(22)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(p.stock !== undefined && p.stock <= 0 ? '#D8D8D8' : Theme.PRIMARY)
        .borderRadius({ topLeft: 4, bottomRight: 4 })
        .margin({ left: 4 })
        .onClick(() => {
          if (p.stock !== undefined && p.stock <= 0) {
            this.notify('该餐品已售罄');
          } else {
            this.addToCart(p);
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 6 })
    }
    .padding({ left: 4, right: 4, top: 8, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .border({ width: 0.5, color: Theme.DIVIDER })
    .borderRadius(4.2)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  bodyArea() {
    if (this.loading) {
      Column() {
        LoadingProgress().width(34).height(34).color(Theme.PRIMARY)
        Text('菜单加载中…').fontSize(12.5).fontColor(Theme.TEXT_HINT).margin({ top: 10 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.errMsg.length > 0) {
      Column() {
        VectorIcon({ path: Icons.SAD, iconSize: 44, color: '#DDDDDD' })
        Text(this.errMsg).fontSize(12.5).fontColor(Theme.TEXT_HINT).margin({ top: 10 })
        Text('重试')
          .fontSize(12.5)
          .fontColor(Theme.PRIMARY)
          .margin({ top: 12 })
          .onClick(() => this.loadAll())
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Row() {
        if (!this.searching) {
          Scroll() {
            Column() {
              ForEach(this.categories, (c: Category) => {
                this.railItem(c)
              }, (c: Category) => c.id.toString())
            }
            .width('100%')
          }
          .width(76)
          .height('100%')
          .backgroundColor('#F7F7F7')
          .scrollBar(BarState.Off)
        }

        Scroll() {
          Column() {
            Row() {
              Text(this.searching ? ('共 ' + this.searchResult.length + ' 个结果') : this.activeCatName())
                .fontSize(12.5)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
              Text(this.searching ? '' : ('  ' + this.visibleProducts().length + ' 款'))
                .fontSize(10.4)
                .fontColor(Theme.TEXT_HINT)
            }
            .width('100%')
            .padding({ left: 2, right: 2, top: 4, bottom: 8 })

            if (this.visibleProducts().length === 0) {
              Column() {
                VectorIcon({ path: Icons.INBOX, iconSize: 40, color: '#DDDDDD' })
                Text('没有找到相关餐品').fontSize(12.5).fontColor(Theme.TEXT_HINT).margin({ top: 8 })
              }
              .width('100%')
              .padding({ top: 40, bottom: 40 })
              .justifyContent(FlexAlign.Center)
            } else {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(this.visibleProducts(), (p: Product) => {
                  Column() {
                    this.productCard(p)
                  }
                  .width('49%')
                  .margin({ bottom: 8 })
                }, (p: Product) => p.id.toString())
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 6, right: 6, top: 8, bottom: 12 })
        }
        .layoutWeight(1)
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  @Builder
  cartBar() {
    Row() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Row() {
          VectorIcon({
            path: Icons.CART,
            iconSize: 22,
            color: this.cartCount > 0 ? '#FFFFFF' : '#FFFFFF'
          })
        }
        .width(46)
        .height(46)
        .borderRadius(23)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.cartCount > 0 ? Theme.PRIMARY : '#CFCFCF')
        .onClick(() => this.go('pages/CartPage'))

        if (this.cartCount > 0) {
          Text(this.cartCount > 99 ? '99+' : this.cartCount.toString())
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .height(16)
            .constraintSize({ minWidth: 16 })
            .padding({ left: 3, right: 3 })
            .borderRadius(8)
            .backgroundColor('#FFFFFF')
            .border({ width: 0.5, color: Theme.PRIMARY })
            .textAlign(TextAlign.Center)
            .margin({ top: -4, right: -4 })
        }
      }
      .height(46)
      .margin({ left: 2 })

      Column() {
        Row() {
          Text('¥').fontSize(10.4).fontColor(Theme.TEXT)
          Text(this.money(this.cartAmount)).fontSize(17.7).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        }
        .alignItems(VerticalAlign.Bottom)

        Text(this.cartCount > 0 ? ('已选 ' + this.cartCount + ' 件 · ' + pickupLabel(this.pickupType)) : '购物车是空的')
          .fontSize(10.4)
          .fontColor(Theme.TEXT_HINT)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Text('去结算')
        .fontSize(14.6)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .height(36)
        .padding({ left: 24, right: 24 })
        .borderRadius(18)
        .backgroundColor(this.cartCount > 0 ? Theme.PRIMARY : '#D8D8D8')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (this.cartCount > 0) {
            this.go('pages/CartPage');
          } else {
            this.notify('购物车是空的');
          }
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 14, right: 12.5 })
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 0.5 }, color: '#F0F0F0' })
  }

  build() {
    Column() {
      this.headBar()
      this.bodyArea()
      this.cartBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
