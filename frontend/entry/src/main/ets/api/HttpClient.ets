import { Constants } from '../common/Constants';

/**
 * 网络请求统一封装
 * TODO 基于 @kit.NetworkKit 的 http 模块实现 get / post / put / delete
 * TODO 统一处理 baseUrl、超时、请求头、业务码判断、错误提示
 */
export class HttpClient {

  private static readonly BASE_URL: string = Constants.BASE_URL;

  // TODO static get<T>(path: string, params?: Record<string, string>): Promise<T>
  // TODO static post<T>(path: string, body: object): Promise<T>
  // TODO static put<T>(path: string, body: object): Promise<T>
  // TODO static delete<T>(path: string): Promise<T>
}
