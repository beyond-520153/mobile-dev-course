/**
 * 全局常量与主题
 *
 * 配色参照肯德基小程序：主色为 KFC 红，辅色为炸鸡黄，页面底色浅灰、卡片纯白。
 */
export class Constants {

  /**
   * 后端地址。
   *
   * ⚠️ 这里必须按运行环境改：
   *   * 真机调试：改成电脑在局域网里的 IP，当前开发机是 'http://10.205.201.67:8090'
   *     （手机上的 127.0.0.1 指的是手机自己，连不到电脑）
   *   * 模拟器：一般也用宿主机的局域网 IP
   *   * 浏览器打开的联调预览页是同源访问，不受这个常量影响
   *
   * 端口用 8090：8080 在开发机上被另一个常驻程序占用了，详见 backend/application.yml。
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
