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

  private static async send<T>(path: string, method: http.RequestMethod, body?: Object): Promise<T> {
    const url = Constants.BASE_URL + path;
    const request = http.createHttp();
    try {
      const header: Record<string, string> = { 'Content-Type': 'application/json' };
      const options: http.HttpRequestOptions = {
        method: method,
        header: header,
        connectTimeout: Constants.TIMEOUT,
        readTimeout: Constants.TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        extraData: body === undefined ? '' : JSON.stringify(body)
      };

      const response = await request.request(url, options);
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

  static post<T>(path: string, body?: Object): Promise<T> {
    return HttpClient.send<T>(path, http.RequestMethod.POST, body);
  }

  static put<T>(path: string, body: Object): Promise<T> {
    return HttpClient.send<T>(path, http.RequestMethod.PUT, body);
  }

  static remove(path: string): Promise<boolean> {
    return HttpClient.send<boolean>(path, http.RequestMethod.DELETE);
  }
}
