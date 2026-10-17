import { Theme, Constants } from '../common/Constants';
import { Category } from '../model/Category';
import { Product } from '../model/Product';
import { ProductApi } from '../api/ProductApi';
import { CartApi } from '../api/CartApi';
import { UserApi } from '../api/UserApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { CategorySideBar } from '../components/CategorySideBar';
import { ProductCard } from '../components/ProductCard';
import { BottomTabBar } from '../components/BottomTabBar';
import { Icons, VectorIcon } from '../components/VectorIcon';

/**
 * 右侧列表的一行：要么是分类标题，要么是餐品。
 *
 * 之所以把两类行拍平成一个数组，是为了实现肯德基小程序那种
 * 「左侧点分类 → 右侧列表滚到对应分组」的联动。
 */
class MenuRow {
  isHeader: boolean = false;
  title: string = '';
  product: Product | null = null;
}

/**
 * 点餐页
 *
 * 版式：顶部红色栏（品牌 + 门店 + 白色搜索框） → 左侧分类 / 右侧餐品列表
 *      → 底部购物车栏 → 底部 tab。
 *
 * 搜索：输入关键词后左侧分类栏收起，右侧整栏变成结果列表；
 * 后端按「名称 + 描述 + 分类名 + 拼音首字母」匹配（见 /api/products/search）。
 * 取餐方式由入口页 pages/EntryPage 写入 AppStorage，这里只做展示。
 */
@Entry
@Component
struct Index {

  @State categories: Category[] = [];
  @State categoryNames: string[] = [];
  @State rows: MenuRow[] = [];
  @State selectedCategory: number = 0;
  @State loading: boolean = true;
  @State errorMsg: string = '';

  /** 取餐方式，由入口页写入；只影响顶部文案，不参与下单（订单仍按后端默认走） */
  @StorageLink('pickupType') pickupType: string = 'PICKUP';

  /** 搜索关键词 */
  @State keyword: string = '';
  /** 关键词非空即进入搜索态：隐藏分类栏、右侧显示结果 */
  @State searching: boolean = false;
  @State results: Product[] = [];
  @State resultLoading: boolean = false;

  /** 与 AppStorage 双向绑定：登录用户、购物车件数、购物车金额 */
  @StorageLink('userId') userId: number = 0;
  @StorageLink('cartCount') cartCount: number = 0;
  @StorageLink('cartAmount') cartAmount: number = 0;

  private scroller: Scroller = new Scroller();
  /** 每个分类标题在 rows 里的下标，点分类时用它定位 */
  private headerIndexes: number[] = [];
  /** 手动滚列表时置位，避免把程序化滚动又反过来当成用户滚动 */
  private scrollingByTap: boolean = false;
  /** 输入防抖定时器，-1 表示没有待执行的搜索 */
  private searchTimer: number = -1;

  aboutToAppear(): void {
    this.initUser();
    this.loadMenu();
  }

  onPageShow(): void {
    // 从购物车/订单页返回时刷新角标
    CartViewModel.refresh(CartViewModel.currentUserId());
  }

  /** 已经登录就刷新购物车；否则自动登录后端种子里的演示账号，方便直接联调 */
  private async initUser(): Promise<void> {
    const current = CartViewModel.currentUserId();
    if (current > 0) {
      await CartViewModel.refresh(current);
      return;
    }
    try {
      const user = await UserApi.login(Constants.DEMO_USERNAME, Constants.DEMO_PASSWORD);
      CartViewModel.setCurrentUserId(user.id);
      await CartViewModel.refresh(user.id);
    } catch (err) {
      this.errorMsg = `自动登录演示账号失败：${err}`;
    }
  }

  /** 拉菜单：后端一次返回「分类 + 分类下餐品」 */
  private async loadMenu(): Promise<void> {
    this.loading = true;
    try {
      const list: Category[] = await ProductApi.listCategories();
      this.categories = list;
      this.buildRows();
      this.errorMsg = '';
    } catch (err) {
      this.errorMsg = `菜单加载失败：${err}`;
    }
    this.loading = false;
  }

  /** 把「分类 + 餐品」拍平成一行行，同时记下每个分类标题的位置 */
  private buildRows(): void {
    const rows: MenuRow[] = [];
    const headers: number[] = [];
    const names: string[] = [];
    for (let i = 0; i < this.categories.length; i++) {
      const category = this.categories[i];
      names.push(category.name);
      const header = new MenuRow();
      header.isHeader = true;
      header.title = category.name;
      headers.push(rows.length);
      rows.push(header);
      for (let j = 0; j < category.products.length; j++) {
        const product = category.products[j];
        const item = new MenuRow();
        item.isHeader = false;
        item.title = product.name;
        item.product = product;
        rows.push(item);
      }
    }
    this.headerIndexes = headers;
    this.categoryNames = names;
    this.rows = rows;
  }

  /** 点左侧分类：右侧滚到对应分组 */
  private async onCategorySelect(index: number): Promise<void> {
    if (index < 0 || index >= this.headerIndexes.length) {
      return;
    }
    this.selectedCategory = index;
    this.scrollingByTap = true;
    this.scroller.scrollToIndex(this.headerIndexes[index]);
    this.scrollingByTap = false;
  }

  /** 右侧滚到哪，左侧高亮就跟到哪 */
  private onListScroll(start: number): void {
    if (this.scrollingByTap) {
      return;
    }
    for (let i = this.headerIndexes.length - 1; i >= 0; i--) {
      if (this.headerIndexes[i] <= start) {
        if (this.selectedCategory !== i) {
          this.selectedCategory = i;
        }
        return;
      }
    }
  }

  /** 加购：先落库，再刷新底部角标 */
  private async addToCart(product: Product): Promise<void> {
    const uid = CartViewModel.currentUserId();
    if (uid <= 0) {
      this.toast('请先登录');
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    try {
      await CartApi.add({ userId: uid, productId: product.id, quantity: 1 });
      await CartViewModel.refresh(uid);
      this.toast(`已加入 ${product.name}`);
    } catch (err) {
      this.toast(`${err}`);
    }
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
  }

  /* ------------------------------ 搜索 ------------------------------ */

  /** 输入变化：300ms 防抖后打后端；清空则立刻退回分类浏览态 */
  private onKeywordChange(value: string): void {
    this.keyword = value;
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    const kw = value.trim();
    if (kw.length === 0) {
      this.searching = false;
      this.results = [];
      this.resultLoading = false;
      return;
    }
    this.searching = true;
    this.resultLoading = true;
    this.searchTimer = setTimeout(() => {
      this.searchTimer = -1;
      this.doSearch(kw);
    }, 300);
  }

  /** 真正的搜索请求 */
  private async doSearch(keyword: string): Promise<void> {
    try {
      const list: Product[] = await ProductApi.search(keyword);
      // 期间用户又改了词就丢弃这次结果，避免旧响应盖掉新结果
      if (keyword === this.keyword.trim()) {
        this.results = list;
        this.resultLoading = false;
      }
    } catch (err) {
      if (keyword === this.keyword.trim()) {
        this.results = [];
        this.resultLoading = false;
        this.toast(`搜索失败：${err}`);
      }
    }
  }

  /** 点叉号清空 */
  private clearKeyword(): void {
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    this.keyword = '';
    this.searching = false;
    this.results = [];
    this.resultLoading = false;
  }

  /**
   * 取餐方式显示文案
   *
   * 入口页有三个通道（外送到家 / 到店自取 / 开车速取），这里必须三路映射。
   * 以前写成 `pickupType === 'DELIVERY' ? '外送到家' : '到店自取'`，
   * 「开车速取」进来会被错标成「到店自取」。
   */
  private pickupLabel(): string {
    if (this.pickupType === 'DELIVERY') {
      return '外送到家';
    }
    if (this.pickupType === 'DRIVE') {
      return '开车速取';
    }
    return '到店自取';
  }

  @Builder
  topBar() {
    Column() {
      Row() {
        Text('KFC 点餐')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)

        Text('浙江农林大学店')
          .fontSize(12)
          .fontColor('#FFD9DE')
          .margin({ left: 8 })
          .layoutWeight(1)

        // 取餐方式取自入口页的选择，纯展示（KFC 小程序这里也是只读标签）
        // 入口页有三个通道，别用二选一的三元表达式，否则「开车速取」会显示成「到店自取」
        Text(this.pickupLabel())
          .fontSize(11)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(10)
          .backgroundColor('#FFFFFF33')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 白色圆角搜索框
      Row() {
        VectorIcon({ path: Icons.SEARCH, iconSize: 15, color: Theme.TEXT_HINT })

        TextInput({ text: this.keyword, placeholder: '搜索餐品：汉堡 / 咖啡 / YWJ' })
          .placeholderColor(Theme.TEXT_HINT)
          .placeholderFont({ size: 13 })
          .fontSize(13)
          .fontColor(Theme.TEXT)
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .margin({ left: 8 })
          .height(34)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.onKeywordChange(value);
          })

        if (this.keyword.length > 0) {
          VectorIcon({ path: Icons.CLOSE, iconSize: 15, color: Theme.TEXT_HINT })
            .onClick(() => {
              this.clearKeyword();
            })
        }
      }
      .width('100%')
      .height(38)
      .padding({ left: 12, right: 12 })
      .borderRadius(19)
      .backgroundColor(Color.White)
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: Theme.GAP, right: Theme.GAP, top: 10, bottom: 10 })
    .backgroundColor(Theme.PRIMARY)
  }

  @Builder
  cartBar() {
    Row() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          VectorIcon({ path: Icons.CART, iconSize: 22, color: '#FFFFFF' })
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .borderRadius(22)
        .backgroundColor(this.cartCount > 0 ? Theme.PRIMARY : '#CCCCCC')

        if (this.cartCount > 0) {
          Text(`${this.cartCount}`)
            .fontSize(10)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
            .constraintSize({ minWidth: 16 })
            .height(16)
            .padding({ left: 4, right: 4 })
            .borderRadius(8)
            .backgroundColor(Color.White)
            .border({ width: 1, color: Theme.PRIMARY })
            .translate({ x: 2, y: -2 })
        }
      }
      .width(46)
      .height(46)

      Column() {
        Row() {
          Text('合计 ')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
          Text('¥')
            .fontSize(11)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
          Text(`${this.cartAmount.toFixed(2)}`)
            .fontSize(18)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
        }
        .alignItems(VerticalAlign.Bottom)

        Text(this.cartCount > 0 ? '已选 ' + this.cartCount + ' 件' : '购物车是空的')
          .fontSize(10)
          .fontColor(Theme.TEXT_HINT)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/CartPage' });
      })

      Text('选好了')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width(96)
        .height(38)
        .borderRadius(19)
        .backgroundColor(this.cartCount > 0 ? Theme.PRIMARY : '#D0D0D0')
        .onClick(() => {
          if (this.cartCount > 0) {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/CartPage' });
          } else {
            this.toast('先挑点吃的吧');
          }
        })
    }
    .width('100%')
    .height(60)
    .padding({ left: Theme.GAP, right: Theme.GAP })
    .backgroundColor(Theme.CARD)
    .border({ width: { top: 1 }, color: Theme.DIVIDER })
    .alignItems(VerticalAlign.Center)
  }

  /** 搜索态：左侧分类栏收起，整栏显示结果 */
  @Builder
  searchPanel() {
    Column() {
      Row() {
        Text(`共 ${this.results.length} 个结果`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
        Blank()
        Text('清空搜索')
          .fontSize(11)
          .fontColor(Theme.PRIMARY)
          .onClick(() => {
            this.clearKeyword();
          })
      }
      .width('100%')
      .padding({ left: Theme.GAP, right: Theme.GAP, top: 10, bottom: 6 })
      .alignItems(VerticalAlign.Center)

      if (this.resultLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(Theme.PRIMARY)
          Text('正在搜索…')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.results.length === 0) {
        Column() {
          VectorIcon({ path: Icons.INBOX, iconSize: 48, color: '#D8D8D8' })
          Text(`没有找到「${this.keyword}」相关的餐品`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .margin({ top: 10 })
            .textAlign(TextAlign.Center)
            .padding({ left: 24, right: 24 })
          Text('换个词试试，比如「堡」「咖啡」「YWJ」')
            .fontSize(11)
            .fontColor(Theme.TEXT_HINT)
            .margin({ top: 4 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.results, (item: Product) => {
            ListItem() {
              ProductCard({
                product: item,
                onAdd: (product: Product) => {
                  this.addToCart(product);
                }
              })
            }
          }, (item: Product) => `${item.id}-${item.name}`)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(Theme.CARD)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(Theme.BG)
  }

  build() {
    Column() {
      this.topBar()

      Row() {
        if (!this.searching) {
          CategorySideBar({
            categories: this.categoryNames,
            selected: this.selectedCategory,
            onSelect: (index: number) => {
              this.onCategorySelect(index);
            }
          })
            .width(86)
            .height('100%')
        }

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(Theme.PRIMARY)
            Text('正在加载菜单…')
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
              .margin({ top: 8 })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() {
            VectorIcon({ path: Icons.SAD, iconSize: 44, color: Theme.TEXT_HINT })
            Text(this.errorMsg)
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
              .textAlign(TextAlign.Center)
              .margin({ top: 10 })
              .padding({ left: 20, right: 20 })
            Text('重新加载')
              .fontSize(13)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width(100)
              .height(32)
              .borderRadius(16)
              .backgroundColor(Theme.PRIMARY)
              .margin({ top: 14 })
              .onClick(() => {
                this.loadMenu();
              })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.searching) {
          this.searchPanel()
        } else {
          List({ scroller: this.scroller }) {
            ForEach(this.rows, (row: MenuRow, index: number) => {
              ListItem() {
                if (row.isHeader) {
                  Text(row.title)
                    .fontSize(12)
                    .fontColor(Theme.TEXT_SUB)
                    .width('100%')
                    .padding({ left: Theme.GAP, top: 12, bottom: 6 })
                    .backgroundColor(Theme.BG)
                } else if (row.product !== null) {
                  ProductCard({
                    product: row.product,
                    onAdd: (product: Product) => {
                      this.addToCart(product);
                    }
                  })
                }
              }
            }, (row: MenuRow, index: number) => `${index}-${row.title}`)
          }
          .layoutWeight(1)
          .height('100%')
          .backgroundColor(Theme.CARD)
          .scrollBar(BarState.Off)
          .onScrollIndex((start: number, end: number, center: number) => {
            this.onListScroll(start);
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top)

      this.cartBar()

      BottomTabBar({ index: 0 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
