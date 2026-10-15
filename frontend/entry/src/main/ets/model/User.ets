/**
 * 用户 —— 与后端 domain/vo/UserVO.java 字段一一对应
 *
 * token 只在登录/注册的响应里有值，其它接口为 undefined。
 */
export interface User {
  id: number;
  username: string;
  phone?: string;
  nickname?: string;
  avatar?: string;
  role: string;
  status: number;
  createdAt: string;
  token?: string;
}
