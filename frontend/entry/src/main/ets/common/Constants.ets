/**
 * 全局常量与主题
 *
 * 配色参照肯德基小程序：主色为 KFC 红，辅色为炸鸡黄，页面底色浅灰、卡片纯白。
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
   *      → 'http://10.205.201.67:8090'（10.205.201.67 是本机无线网卡 IP，
   *        换网络环境后要重新查：cmd 里 ipconfig 看「无线局域网适配器 WLAN」的 IPv4）
   *      ⚠️ 需要放行 Windows 防火墙的 8090 入站，否则手机连不上（见 README 第五章）
   *
   *   ③ DevEco 模拟器
   *      先试 'http://10.0.2.2:8090'（模拟器访问宿主机的约定地址），
   *      不通再用上面的局域网 IP。
   *
   * 端口用 8090：8080 在开发机上被另一个常驻程序占用了，详见 backend/application.yml。
   * 手机上的 127.0.0.1 指的是手机自己，所以方案 ②③ 都不能写 127.0.0.1（方案①除外，那是 hdc 转发的）。
   */
  static readonly BASE_URL: string = 'http://10.205.201.67:8090';

  /** 接口统一前缀 */
  static readonly API_PREFIX: string = '/api';

  /** 请求超时（毫秒） */
  static readonly TIMEOUT: number = 10000;

  /** 演示账号：后端种子数据里就有，首页会自动用它登录以便直接联调 */
  static readonly DEMO_USERNAME: string = 'demo';
  static readonly DEMO_PASSWORD: string = '123456';
}

/** 主题色 */
export class Theme {

  /** KFC 红 —— 顶栏、价格、主按钮 */
  static readonly PRIMARY: string = '#E4002B';
  /** 深红 —— 按下态 */
  static readonly PRIMARY_DARK: string = '#C10023';
  /** 炸鸡黄 —— 会员/角标点缀 */
  static readonly ACCENT: string = '#FFC72C';

  /** 页面底色 */
  static readonly BG: string = '#F5F5F5';
  /** 卡片白 */
  static readonly CARD: string = '#FFFFFF';
  /** 侧边分类栏底色 */
  static readonly SIDEBAR_BG: string = '#F7F7F7';

  /** 主文字 */
  static readonly TEXT: string = '#1A1A1A';
  /** 次要文字 */
  static readonly TEXT_SUB: string = '#8A8A8A';
  /** 极浅文字 */
  static readonly TEXT_HINT: string = '#B5B5B5';
  /** 分隔线 */
  static readonly DIVIDER: string = '#EFEFEF';

  /** 餐品占位图底色 */
  static readonly THUMB_BG: string = '#FFF4E0';

  /** 页面左右留白 */
  static readonly GAP: number = 12;
}
