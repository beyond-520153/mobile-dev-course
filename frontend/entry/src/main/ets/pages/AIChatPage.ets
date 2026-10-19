import { Constants, Theme } from '../common/Constants';
import { Icons, VectorIcon } from '../components/VectorIcon';
import { AiApi } from '../api/AiApi';
import { CartApi } from '../api/CartApi';
import { CartViewModel } from '../viewmodel/CartViewModel';
import { AiPick, AiStore } from '../model/AiRecommend';
import { Product } from '../model/Product';

/** 每行放几张卡：截图为 3 列 × 2 行 */
const COLUMNS: number = 3;

/**
 * AI 点餐页
 *
 * 版式照参考截图重绘，自上而下：
 *   深空联名 banner（返回键 + 「默认语音」胶囊 + KFC｜三体）
 *   → 两条消息气泡（小K 自我介绍 / 本次推荐话术 + 喇叭）
 *   → 浅粉推荐卡（门店行 + 3×2 餐品网格，每张卡带「选N」贴纸）
 *   → 底部固定操作区（换一换 / 开启新对话，九宫格 / 按住说话 / 声波）
 *
 * 数据来自后端 POST /api/ai/recommend：模型只挑「哪几样 + 一句话」，
 * 图片、价格、会员价都由后端回表补，所以这里拿到的卡一定能加购。
 * 模型不可用时后端会降级返回本地推荐（degraded=true），页面照常展示，
 * 只在气泡上方补一行浅色提示，不打断用户。
 */
@Entry
@Component
struct AIChatPage {

  /** 取餐方式，入口页写入；只影响话术（自取 / 外送 / 车速取） */
  @StorageLink('pickupType') pickupType: string = 'PICKUP';
  /** 当前登录用户，加购要用 */
  @StorageLink('userId') userId: number = 0;
  @StorageLink('cartCount') cartCount: number = 0;

  @State items: AiPick[] = [];
  @State reply: string = '';
  @State store: AiStore | null = null;
  @State loading: boolean = true;
  @State degraded: boolean = false;
  @State degradeReason: string = '';
  @State errorMsg: string = '';

  /** 文字输入浮层 */
  @State asking: boolean = false;
  @State draft: string = '';
  /** 「按住说话」按下态，只做视觉反馈 */
  @State pressing: boolean = false;
  /** 正在加购的餐品 id，防连点 */
  @State addingId: number = 0;

  /** banner 画布 */
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private scroller: Scroller = new Scroller();
  private readonly bannerHeight: number = 106;

  aboutToAppear(): void {
    this.recommend('');
  }

  /* ============================== 数据 ============================== */

  /**
   * 要一组推荐
   *
   * @param message 空串表示首屏；「换一换」也原样传下去，让模型换一组
   */
  private async recommend(message: string): Promise<void> {
    this.loading = true;
    this.errorMsg = '';
    try {
      const res = await AiApi.recommend(message, this.pickupType);
      this.items = res.items;
      this.reply = res.reply;
      this.store = res.store;
      this.degraded = res.degraded === true;
      this.degradeReason = res.degradeReason === undefined ? '' : res.degradeReason;
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : '推荐失败，请稍后重试';
      this.errorMsg = msg;
      this.items = [];
    } finally {
      this.loading = false;
    }
  }

  /** 点卡片 = 加入餐车 */
  private async addToCart(item: AiPick): Promise<void> {
    if (this.userId <= 0) {
      this.toast('请先登录后再点餐');
      return;
    }
    if (this.addingId === item.product.id) {
      return;
    }
    this.addingId = item.product.id;
    try {
      await CartApi.add({ userId: this.userId, productId: item.product.id, quantity: 1 });
      await CartViewModel.refresh(this.userId);
      this.toast(`已加入餐车：${item.product.name}`);
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : '加入餐车失败';
      this.toast(msg);
    } finally {
      this.addingId = 0;
    }
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 });
    } catch (e) {
      console.warn('showToast failed: ' + JSON.stringify(e));
    }
  }

  /**
   * 返回入口页
   *
   * 这里不用 router.back()：AI 页也可能是被 replaceUrl 打开的（栈里只有自己），
   * 那时 back 什么都不做，用户会被困住。统一 replaceUrl 回入口页，
   * 无论从哪条路径进来都一定退得出去。
   */
  private goHome(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/EntryPage' });
    } catch (e) {
      console.error('replaceUrl EntryPage failed: ' + JSON.stringify(e));
    }
  }

  /* ============================== 工具 ============================== */

  /** 图片相对路径补服务端地址，与 ProductThumb 同一套规则 */
  private imageSrc(image: string | undefined): string {
    if (image === undefined || image.length === 0) {
      return '';
    }
    if (image.startsWith('http')) {
      return image;
    }
    if (image.startsWith('/')) {
      return Constants.BASE_URL + image;
    }
    return '';
  }

  /** 现价：整数不带小数点，非整数留一位（19 / 29.9） */
  private priceMain(product: Product): string {
    const v: number = Number(product.price);
    return Number.isInteger(v) ? v.toFixed(0) : v.toFixed(1);
  }

  /** 划线原价，仅当原价确实高于现价时返回，否则空串 */
  private priceOrigin(product: Product): string {
    const o: number | undefined = product.originPrice;
    if (o === undefined) {
      return '';
    }
    const value: number = Number(o);
    if (value <= Number(product.price)) {
      return '';
    }
    return Number.isInteger(value) ? value.toFixed(0) : value.toFixed(1);
  }

  /** 会员价文案，没有就空串（未登录 / 未持卡） */
  private memberText(product: Product): string {
    const text: string | undefined = product.memberPriceText;
    return text === undefined ? '' : text;
  }

  /** 把一维卡片数组按 3 个一行切开 */
  private rowsOf(list: AiPick[]): AiPick[][] {
    const rows: AiPick[][] = [];
    for (let i = 0; i < list.length; i += COLUMNS) {
      rows.push(list.slice(i, i + COLUMNS));
    }
    return rows;
  }

  /* ============================ banner 绘制 ============================ */

  /**
   * 深空背景
   *
   * 参考图是一张「KFC × 三体」联名视觉：近黑的深空、右下角紫色星云、
   * 左上角品牌红微光、散落星点。原图是位图素材，这里用 Canvas 手绘等效氛围，
   * 不引入版权图。星点用固定种子的伪随机，保证每次重绘位置一致，不会闪。
   */
  private drawSky(): void {
    const c = this.ctx;
    const w: number = c.width;
    const h: number = c.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    c.clearRect(0, 0, w, h);

    const base = c.createLinearGradient(0, 0, w, h);
    base.addColorStop(0, '#07070F');
    base.addColorStop(0.45, '#11102A');
    base.addColorStop(1, '#211236');
    c.fillStyle = base;
    c.fillRect(0, 0, w, h);

    // 右下星云
    const halo = c.createRadialGradient(w * 0.84, h * 0.82, 2, w * 0.84, h * 0.82, h * 1.05);
    halo.addColorStop(0, 'rgba(150, 92, 255, 0.42)');
    halo.addColorStop(0.55, 'rgba(88, 50, 158, 0.16)');
    halo.addColorStop(1, 'rgba(0, 0, 0, 0)');
    c.fillStyle = halo;
    c.fillRect(0, 0, w, h);

    // 左上品牌红微光
    const glow = c.createRadialGradient(w * 0.1, h * 0.05, 2, w * 0.1, h * 0.05, h * 0.9);
    glow.addColorStop(0, 'rgba(228, 0, 43, 0.30)');
    glow.addColorStop(1, 'rgba(228, 0, 43, 0)');
    c.fillStyle = glow;
    c.fillRect(0, 0, w, h);

    // 星点（固定种子）
    let seed: number = 20261019;
    const rand = (): number => {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    };
    for (let i = 0; i < 90; i++) {
      const x: number = rand() * w;
      const y: number = rand() * h;
      const r: number = rand() * 1.1 + 0.3;
      const alpha: number = 0.25 + rand() * 0.7;
      c.beginPath();
      c.arc(x, y, r, 0, Math.PI * 2);
      c.fillStyle = `rgba(255, 255, 255, ${alpha.toFixed(2)})`;
      c.fill();
    }

    // 右上角一颗淡紫星球，压住星云的重心
    const px: number = w * 0.87;
    const py: number = h * 0.24;
    const pr: number = 24;
    const planet = c.createRadialGradient(px - pr * 0.35, py - pr * 0.35, 1, px, py, pr);
    planet.addColorStop(0, 'rgba(222, 202, 255, 0.9)');
    planet.addColorStop(0.55, 'rgba(128, 92, 210, 0.55)');
    planet.addColorStop(1, 'rgba(38, 20, 68, 0.05)');
    c.beginPath();
    c.arc(px, py, pr, 0, Math.PI * 2);
    c.fillStyle = planet;
    c.fill();
  }

  /* ============================== 结构 ============================== */

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.banner()
        this.chatArea()
        this.actions()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

      if (this.asking) {
        this.askPanel()
      }
    }
    .width('100%')
    .height('100%')
  }

  /* ------------------------------ 顶部 banner ------------------------------ */

  @Builder
  banner() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.drawSky();
        })

      Column() {
        // 返回 + 语音音色
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(32)
              .height(32)
              .fill('rgba(255, 255, 255, 0.16)')
            VectorIcon({ path: Icons.ARROW_BACK, iconSize: 17, color: '#FFFFFF' })
          }
          .width(32)
          .height(32)
          .onClick(() => {
            this.goHome();
          })

          Blank()

          // 「默认语音」胶囊：点一下提示音色可切换
          Row() {
            VectorIcon({ path: Icons.VOLUME, iconSize: 13, color: '#FFFFFF' })
            Text('默认语音')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .margin({ left: 4 })
            VectorIcon({ path: Icons.CHEVRON_DOWN, iconSize: 14, color: '#EDEDED' })
              .margin({ left: 1 })
          }
          .height(28)
          .padding({ left: 10, right: 8 })
          .borderRadius(14)
          .backgroundColor('rgba(255, 255, 255, 0.14)')
          .onClick(() => {
            this.toast('当前只有「小K」默认音色');
          })
        }
        .width('100%')
        .height(32)

        // 联名主视觉
        Column() {
          Row() {
            Text('KFC')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontStyle(FontStyle.Italic)
              .fontColor('#FFFFFF')
              .letterSpacing(0.6)
            Text('｜')
              .fontSize(15)
              .fontColor('rgba(255,255,255,0.5)')
              .margin({ left: 5, right: 5 })
            Text('三体')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .letterSpacing(3)
          }
          .alignItems(VerticalAlign.Center)

          Text('天生翅粉 宇宙同频')
            .fontSize(11)
            .fontColor('rgba(226, 218, 255, 0.86)')
            .letterSpacing(1.2)
            .margin({ top: 5 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 6 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })
    }
    .width('100%')
    .height(this.bannerHeight)
  }

  /* ------------------------------ 消息与推荐 ------------------------------ */

  @Builder
  chatArea() {
    Scroll(this.scroller) {
      Column() {
        // 气泡 1：小K 自我介绍
        this.bubble('Hi，我是小K！看看今天的推荐吧！', false)

        // 气泡 2：本次推荐话术 + 喇叭
        this.bubble(this.talkText(), true)

        if (this.degraded && this.degradeReason.length > 0) {
          Text(this.degradeReason)
            .fontSize(11)
            .fontColor(Theme.TEXT_HINT)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
        }

        if (this.loading) {
          this.loadingCards()
        } else if (this.errorMsg.length > 0) {
          this.errorBlock()
        } else if (this.items.length > 0) {
          this.recommendCard()
        }

        // 底部留白，别让最后一排卡贴住操作区
        Text('')
          .height(14)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10 })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  /** 第二个气泡的文案：门店 + 模型回复 + 操作提示 */
  private talkText(): string {
    const name: string = this.store === null ? '农林大学餐厅' : this.store.name;
    if (this.reply.length > 0) {
      return `已为您选择【${name}】，${this.reply}你可以点选其中一个，或直接对我说「选1和2」：`;
    }
    return `已为您选择【${name}】，为您推荐以下餐品，你可以点选其中一个，或直接对我说「选1和2」：`;
  }

  /**
   * 消息气泡
   *
   * 参考图里气泡是白底、圆角 14、左上角略小（表示来自右侧的自己人说出去的不对称感），
   * 这里保持左上 4、其余 14，气泡之间的间距 8。
   */
  @Builder
  bubble(text: string, withSpeaker: boolean) {
    Row() {
      Column() {
        Text(text)
          .fontSize(13.5)
          .lineHeight(19)
          .fontColor(Theme.TEXT)
          .width('100%')

        if (withSpeaker) {
          Row() {
            VectorIcon({ path: Icons.VOLUME, iconSize: 15, color: Theme.PRIMARY })
          }
          .margin({ top: 5 })
          .onClick(() => {
            this.toast('语音播报暂未接入，先看文字吧');
          })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 11, right: 11, top: 8, bottom: 8 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 4, topRight: 14, bottomLeft: 14, bottomRight: 14 })
      .shadow({ radius: 8, color: '#0F000000', offsetX: 0, offsetY: 2 })
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 6 })
  }

  /* ------------------------------ 推荐卡 ------------------------------ */

  @Builder
  recommendCard() {
    Column() {
      // 门店行
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(24)
            .height(24)
            .fill(Theme.PRIMARY)
          VectorIcon({ path: Icons.STORE, iconSize: 13, color: '#FFFFFF' })
        }
        .width(24)
        .height(24)

        Text(this.store === null ? '农林大学餐厅' : this.store.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .margin({ left: 7 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 定位圈：红圈 + 红点，表示「已选这家店」
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(15)
            .height(15)
            .fillOpacity(0)
            .stroke(Theme.PRIMARY)
            .strokeWidth(1.5)
          Circle()
            .width(6)
            .height(6)
            .fill(Theme.PRIMARY)
        }
        .width(15)
        .height(15)
        .margin({ left: 6 })

        Blank()

        VectorIcon({ path: Icons.CHEVRON_RIGHT, iconSize: 16, color: Theme.TEXT_HINT })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 取餐方式 + 地址 + 距离
      Row() {
        Text(this.store === null ? '自取' : this.store.pickupText)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)

        Text('｜')
          .fontSize(11)
          .fontColor('#D8D8D8')
          .margin({ left: 5, right: 5 })

        Text(this.store === null ? '' : this.store.address)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text(this.store === null ? '' : this.store.distance)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .margin({ left: 6 })
      }
      .width('100%')
      .margin({ top: 7 })
      .alignItems(VerticalAlign.Center)

      // 3×2 餐品网格
      Column() {
        ForEach(this.rowsOf(this.items), (row: AiPick[], rowIndex: number) => {
          Row() {
            ForEach(row, (item: AiPick) => {
              this.pickCard(item)
            }, (item: AiPick) => `${item.product.id}`)

            // 最后一行不满 3 个时补空位，保持卡片等宽左对齐
            if (row.length < COLUMNS) {
              ForEach(new Array<number>(COLUMNS - row.length).fill(0),
                (blank: number, blankIndex: number) => {
                  Text('')
                    .layoutWeight(1)
                    .margin({ left: 6 })
                }, (blank: number, blankIndex: number) => `blank-${blankIndex}`)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .margin({ top: rowIndex === 0 ? 0 : 6 })
        }, (row: AiPick[]) => `row-${row[0].product.id}`)
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
    .padding(9)
    .backgroundColor('#FFF5F6')
    .borderRadius(16)
    .margin({ top: 2 })
  }

  /**
   * 单张餐品卡
   *
   * 结构与参考图一致：白底圆角 → 顶部「选N」粉色贴纸压在图上方 →
   * 图 → 名称（两行）→ 现价 + 划线原价。
   */
  @Builder
  pickCard(item: AiPick) {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        if (this.imageSrc(item.product.image).length > 0) {
          Image(this.imageSrc(item.product.image))
            .width('100%')
            .height(68)
            .objectFit(ImageFit.Contain)
            .borderRadius(8)
            .backgroundColor(Theme.THUMB_BG)
        } else {
          Column() {
            VectorIcon({ path: Icons.BURGER, iconSize: 30, color: '#E0B57A' })
          }
          .width('100%')
          .height(68)
          .justifyContent(FlexAlign.Center)
          .borderRadius(8)
          .backgroundColor(Theme.THUMB_BG)
        }

        // 「选N」贴纸
        Text(item.label)
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .linearGradient({
            angle: 180,
            colors: [['#FF8C9C', 0.0], ['#FF4D6A', 1.0]]
          })
      }
      .width('100%')

      Text(item.product.name)
        .fontSize(11)
        .lineHeight(15)
        .fontColor(Theme.TEXT)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(26)
        .margin({ top: 3 })

      Column() {
        Row() {
          Text('¥')
            .fontSize(9)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
          Text(this.priceMain(item.product))
            .fontSize(14)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
          Text('起')
            .fontSize(9)
            .fontColor(Theme.PRIMARY)
            .margin({ left: 1 })
        }
        .alignItems(VerticalAlign.Bottom)

        if (this.priceOrigin(item.product).length > 0) {
          Text(`¥${this.priceOrigin(item.product)}`)
            .fontSize(9)
            .fontColor('#A8A8A8')
            .decoration({ type: TextDecorationType.LineThrough, color: '#A8A8A8' })
            .margin({ top: 1 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 2 })
    }
    .layoutWeight(1)
    .padding({ left: 4, right: 4, top: 4, bottom: 2 })
    .backgroundColor('#FFFFFF')
    .borderRadius(10)
    .margin({ left: 6 })
    .onClick(() => {
      this.addToCart(item);
    })
  }

  /** 加载态：6 个呼吸的灰色占位 */
  @Builder
  loadingCards() {
    Column() {
      Row() {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(Theme.PRIMARY)
        Text('小K 正在翻菜单…')
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
          .margin({ left: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Column() {
        Row() {
          ForEach([0, 1, 2], (i: number) => {
            Text('')
              .layoutWeight(1)
              .height(108)
              .borderRadius(10)
              .backgroundColor('#FFFFFF')
              .margin({ left: i === 0 ? 0 : 6 })
          }, (i: number) => `sk-${i}`)
        }
        .width('100%')
        .margin({ top: 10 })

        Row() {
          ForEach([0, 1, 2], (i: number) => {
            Text('')
              .layoutWeight(1)
              .height(108)
              .borderRadius(10)
              .backgroundColor('#FFFFFF')
              .margin({ left: i === 0 ? 0 : 6 })
          }, (i: number) => `sk2-${i}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#FFF5F6')
      .borderRadius(16)
    }
    .width('100%')
  }

  /** 失败态 */
  @Builder
  errorBlock() {
    Column() {
      VectorIcon({ path: Icons.SAD, iconSize: 26, color: '#D8D8D8' })
      Text(this.errorMsg)
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .margin({ top: 6 })
      Text('重新试试')
        .fontSize(12)
        .fontColor(Theme.PRIMARY)
        .margin({ top: 8 })
        .onClick(() => {
          this.recommend('');
        })
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .backgroundColor('#FFF5F6')
    .borderRadius(16)
  }

  /* ------------------------------ 底部操作区 ------------------------------ */

  @Builder
  actions() {
    Column() {
      // 第一行：换一换 / 开启新对话
      Row() {
        this.chip('换一换', Icons.REFRESH, 'refresh')
        this.chip('开启新对话', Icons.CHAT, 'new')
        Blank()
      }
      .width('100%')

      // 第二行：九宫格 / 按住说话 / 声波
      Row() {
        // 九宫格：切到文字输入
        Stack({ alignContent: Alignment.Center }) {
          VectorIcon({ path: Icons.GRID, iconSize: 18, color: Theme.TEXT })
        }
        .width(44)
        .height(44)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#EDEDED' })
        .onClick(() => {
          this.asking = true;
        })

        // 按住说话（红胶囊）
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(20)
              .height(20)
              .fill('rgba(255,255,255,0.22)')
            Text('K')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontStyle(FontStyle.Italic)
              .fontColor('#FFFFFF')
          }
          .width(20)
          .height(20)

          Text(this.pressing ? '松开 结束' : '按住说话')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .margin({ left: 8 })
        }
        .layoutWeight(1)
        .height(46)
        .justifyContent(FlexAlign.Center)
        .borderRadius(23)
        .margin({ left: 10, right: 10 })
        .linearGradient({
          angle: 90,
          colors: [['#F5333F', 0.0], ['#E4002B', 0.55], ['#C9002A', 1.0]]
        })
        .shadow({ radius: 10, color: '#33E4002B', offsetX: 0, offsetY: 4 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressing = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressing = false;
            this.toast('语音识别暂未接入，先用文字告诉小K');
            this.asking = true;
          }
        })

        // 声波键：同样进文字输入
        Stack({ alignContent: Alignment.Center }) {
          VectorIcon({ path: Icons.WAVE, iconSize: 18, color: Theme.TEXT })
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#EDEDED' })
        .onClick(() => {
          this.asking = true;
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 10 })

      // home indicator
      Text('')
        .width(120)
        .height(4)
        .borderRadius(2)
        .backgroundColor('#1A1A1A')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 2 })
    .backgroundColor('#FFFFFF')
  }

  /** 浅色胶囊按钮 */
  @Builder
  chip(label: string, icon: string, action: string) {
    Row() {
      VectorIcon({ path: icon, iconSize: 13, color: Theme.TEXT_SUB })
      Text(label)
        .fontSize(12)
        .fontColor(Theme.TEXT)
        .margin({ left: 4 })
    }
    .height(32)
    .padding({ left: 12, right: 12 })
    .borderRadius(16)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#EDEDED' })
    .margin({ right: 8 })
    .onClick(() => {
      this.onChip(action);
    })
  }

  private onChip(action: string): void {
    if (action === 'refresh') {
      this.recommend('换一换');
      return;
    }
    // 开启新对话：先把上一轮的状态清干净，再按首屏重新问一次
    this.items = [];
    this.reply = '';
    this.degraded = false;
    this.degradeReason = '';
    this.recommend('');
  }

  /* ------------------------------ 文字输入浮层 ------------------------------ */

  @Builder
  askPanel() {
    Column() {
      Column() {
        Text('告诉小K你想吃什么')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)

        Text('比如「来点辣的，两个人吃」「30 元以内」「不要饮料」')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 4 })

        TextInput({ placeholder: '说说你的口味和预算', text: this.draft })
          .height(44)
          .fontSize(14)
          .backgroundColor('#F7F7F7')
          .borderRadius(10)
          .margin({ top: 12 })
          .onChange((value: string) => {
            this.draft = value;
          })

        Row() {
          Text('取消')
            .fontSize(14)
            .fontColor(Theme.TEXT_SUB)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(40)
            .onClick(() => {
              this.asking = false;
              this.draft = '';
            })

          Text('让小K推荐')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .height(40)
            .textAlign(TextAlign.Center)
            .borderRadius(20)
            .backgroundColor(Theme.PRIMARY)
            .onClick(() => {
              const text: string = this.draft.trim();
              this.asking = false;
              this.draft = '';
              this.recommend(text);
            })
        }
        .width('100%')
        .margin({ top: 14 })
        .alignItems(VerticalAlign.Center)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .width('86%')
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }
}
