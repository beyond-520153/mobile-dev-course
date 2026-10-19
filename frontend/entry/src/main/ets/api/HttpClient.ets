import { http } from '@kit.NetworkKit';
import { Constants } from '../common/Constants';
import { ApiResult } from '../model/ApiResult';

/**
 * 网络请求统一封装
 *
 * 统一处理：baseUrl 拼接、超时、请求头、JSON 解析、业务码判断。
 * 约定：调用方拿到的是 Result.data，业务码不是 200 或 HTTP 不通都会 throw Error，
 * 页面里用 try-catch 接住并把 message 弹给用户即可。
 */
export class HttpClient {

  private static async send<T>(path: string, method: http.RequestMethod,
                               body?: Object, timeout?: number): Promise<T> {
    const url = Constants.BASE_URL + path;
    // 默认 10 秒；AI 分析这类慢接口可以把 timeout 传大一点
    const limit = timeout === undefined ? Constants.TIMEOUT : timeout;
    const request = http.createHttp();
    try {
      const header: Record<string, string> = { 'Content-Type': 'application/json' };
      // 登录后 token 存在 AppStorage 里，所有请求统一自动带上，业务代码不用关心鉴权
      const token: string | undefined = AppStorage.get<string>('token');
      if (token !== undefined && token.length > 0) {
        header['Authorization'] = `Bearer ${token}`;
      }
      const options: http.HttpRequestOptions = {
        method: method,
        header: header,
        connectTimeout: limit,
        readTimeout: limit,
        expectDataType: http.HttpDataType.STRING,
        extraData: body === undefined ? '' : JSON.stringify(body)
      };

      const response = await request.request(url, options);
      if (response.responseCode === 401) {
        // token 过期或被登出：清掉本地 token，让页面重新走登录
        AppStorage.setOrCreate<string>('token', '');
        throw new Error('登录已过期，请重新登录');
      }
      if (response.responseCode !== 200) {
        throw new Error(`服务端返回 HTTP ${response.responseCode}`);
      }

      const text = response.result as string;
      const result = JSON.parse(text) as ApiResult<T>;
      if (result === null || result === undefined) {
        throw new Error('响应内容解析失败');
      }
      if (result.code !== 200) {
        throw new Error(result.message === undefined ? '请求失败' : result.message);
      }
      return result.data;
    } finally {
      request.destroy();
    }
  }

  static get<T>(path: string): Promise<T> {
    return HttpClient.send<T>(path, http.RequestMethod.GET);
  }

  /**
   * POST
   *
   * @param timeout 可选超时（毫秒）。AI 推荐要等模型出结果，单独放宽到 30~40 秒，
   *                不然还在思考就被本地 10 秒超时掐断，白白降级
   */
  static post<T>(path: string, body?: Object, timeout?: number): Promise<T> {
    return HttpClient.send<T>(path, http.RequestMethod.POST, body, timeout);
  }

  static put<T>(path: string, body: Object): Promise<T> {
    return HttpClient.send<T>(path, http.RequestMethod.PUT, body);
  }

  static remove(path: string): Promise<boolean> {
    return HttpClient.send<boolean>(path, http.RequestMethod.DELETE);
  }
}
