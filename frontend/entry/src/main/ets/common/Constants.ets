/**
 * 全局常量与主题
 *
 * 配色与尺寸取自肯德基手机端 H5（order.kfc.com.cn/preorder-taro）的运行期 CSS：
 * 主色 rgb(228,0,48)；正文 rgb(35,30,31)；次要 #666；提示 #999；
 * 页面底色 #F8F8F8；卡片圆角 0.5rem（390 视口下 10.4vp）。
 */
export class Constants {

  /**
   * 后端地址（**调试前必须按连法改这一行**）
   *
   * 三种连法，选一种把下面的 BASE_URL 改成对应值：
   *
   *   ① 真机 + USB 数据线（推荐，不受防火墙影响）
   *      电脑上先执行：hdc rport tcp:8090 tcp:8090
   *      → 'http://127.0.0.1:8090'
   *
   *   ② 真机 + 与电脑同一个 WLAN
   *      → 'http://10.205.201.67:8090'（本机无线网卡 IP，换网络要重新查）
   *
   *   ③ DevEco 模拟器
   *      → 'http://10.0.2.2:8090'
   *
   * 端口用 8090：8080 在开发机上被另一个常驻程序占用了。
   * 手机上的 127.0.0.1 指手机自己，②③ 都不能写 127.0.0.1（① 除外，那是 hdc 转发的）。
   */
  static readonly BASE_URL: string = 'http://10.205.201.67:8090';

  /** 接口统一前缀 */
  static readonly API_PREFIX: string = '/api';

  /** 请求超时（毫秒） */
  static readonly TIMEOUT: number = 10000;

  /** 演示账号 */
  static readonly DEMO_USERNAME: string = 'demo';
  static readonly DEMO_PASSWORD: string = '123456';
}

/** 主题色与尺寸（全部对齐官方 H5） */
export class Theme {

  /** 主色 —— 官方 rgb(228,0,48) */
  static readonly PRIMARY: string = '#E40030';
  /** 按下态 */
  static readonly PRIMARY_DARK: string = '#C1002A';
  /** 会员金 */
  static readonly ACCENT: string = '#F8E2B7';

  /** 页面底色 */
  static readonly BG: string = '#F8F8F8';
  /** 卡片白 */
  static readonly CARD: string = '#FFFFFF';
  /** 分类栏底色 */
  static readonly SIDEBAR_BG: string = '#F7F7F7';

  /** 主文字 rgb(35,30,31) */
  static readonly TEXT: string = '#231E1F';
  /** 次要文字 */
  static readonly TEXT_SUB: string = '#666666';
  /** 提示文字 */
  static readonly TEXT_HINT: string = '#999999';
  /** 分隔线 */
  static readonly DIVIDER: string = '#E6E6E6';

  /** 餐品占位底 */
  static readonly THUMB_BG: string = '#FFF8EE';

  /** 卡片圆角 */
  static readonly RADIUS: number = 10.4;
  /** 页面左右留白 */
  static readonly GAP: number = 12.5;
  /** 卡片阴影 */
  static readonly SHADOW: string = 'rgba(217,217,217,0.5)';
}

/** 门店信息：浙江农林大学店（真实门店） */
export class StoreInfo {
  static readonly NAME: string = '肯德基(农林大学店)';
  static readonly SHORT: string = '农林大学店';
  static readonly ADDR: string = '杭州市临安区锦北街道武肃街666号 浙江农林大学东湖食堂1层外侧档口';
  static readonly HOURS: string = '06:30-22:00';
  static readonly DIST: string = '0.1km';
  static readonly TAGS: string[] = ['到店自取', '外送到家', '开车速取'];
}

/** 取餐方式三路文案（漏一个就会错显「到店自取」） */
export function pickupLabel(type: string): string {
  if (type === 'DELIVERY') {
    return '外送到家';
  }
  if (type === 'DRIVE') {
    return '开车速取';
  }
  return '到店自取';
}
