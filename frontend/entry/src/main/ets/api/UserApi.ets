import { HttpClient } from './HttpClient';
import { User } from '../model/User';

/**
 * 修改资料入参，对应后端 domain/dto/UserUpdateDTO.java
 */
export interface UserUpdateBody {
  phone?: string;
  nickname?: string;
  avatar?: string;
}

/**
 * 用户 相关接口
 */
export class UserApi {

  /** 登录：成功后返回的 User 里带 token，同时写入 AppStorage 供 HttpClient 自动携带 */
  static async login(username: string, password: string): Promise<User> {
    const body: LoginBody = { username: username, password: password };
    const user = await HttpClient.post<User>('/api/users/login', body);
    UserApi.rememberToken(user);
    return user;
  }

  static async register(username: string, password: string, phone: string, nickname: string): Promise<User> {
    const body: RegisterBody = {
      username: username,
      password: password,
      phone: phone,
      nickname: nickname
    };
    const user = await HttpClient.post<User>('/api/users/register', body);
    UserApi.rememberToken(user);
    return user;
  }

  /** 把 token 落到全局存储；空值表示已登出 / 过期 */
  private static rememberToken(user: User): void {
    const token: string | undefined = user.token;
    AppStorage.setOrCreate<string>('token', token === undefined ? '' : token);
  }

  /**
   * 登出
   *
   * JWT 本身无法撤销，所以真正让 token 失效的是后端的 Redis 会话：
   * 这里必须先调接口删掉会话，否则本地清了 token，服务端那条还活到自然过期。
   */
  static async logout(): Promise<void> {
    try {
      await HttpClient.post<boolean>('/api/users/logout');
    } catch (err) {
      // 会话可能已过期，登出失败不该挡住用户退出
      console.error(`登出请求失败: ${err}`);
    }
    AppStorage.setOrCreate<string>('token', '');
  }

  static detail(id: number): Promise<User> {
    return HttpClient.get<User>(`/api/users/${id}`);
  }

  static list(): Promise<User[]> {
    return HttpClient.get<User[]>('/api/users');
  }

  static update(id: number, body: UserUpdateBody): Promise<User> {
    return HttpClient.put<User>(`/api/users/${id}`, body);
  }

  static remove(id: number): Promise<boolean> {
    return HttpClient.remove(`/api/users/${id}`);
  }
}

/** 登录请求体，对应后端 domain/dto/LoginDTO.java */
interface LoginBody {
  username: string;
  password: string;
}

/** 注册请求体，对应后端 domain/dto/UserRegisterDTO.java */
interface RegisterBody {
  username: string;
  password: string;
  phone: string;
  nickname: string;
}
