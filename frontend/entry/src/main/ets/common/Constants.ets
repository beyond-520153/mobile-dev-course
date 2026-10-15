/**
 * 全局常量
 */
export class Constants {

  /** 后端地址。真机调试要改成电脑在局域网里的 IP；模拟器地址规则单独确认 */
  static readonly BASE_URL: string = 'http://127.0.0.1:8080';

  /** 请求超时（毫秒） */
  static readonly TIMEOUT: number = 10000;

  /** 分页默认条数 */
  static readonly PAGE_SIZE: number = 10;

  // TODO 补充主题色、图片占位符等常量
}
