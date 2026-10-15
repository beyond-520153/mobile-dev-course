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

  /** 登录：成功后返回的 User 里带 token */
  static login(username: string, password: string): Promise<User> {
    const body: LoginBody = { username: username, password: password };
    return HttpClient.post<User>('/api/users/login', body);
  }

  static register(username: string, password: string, phone: string, nickname: string): Promise<User> {
    const body: RegisterBody = {
      username: username,
      password: password,
      phone: phone,
      nickname: nickname
    };
    return HttpClient.post<User>('/api/users/register', body);
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
