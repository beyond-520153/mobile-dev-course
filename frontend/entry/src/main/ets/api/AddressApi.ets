import { HttpClient } from './HttpClient';
import { Address } from '../model/Address';

/**
 * 地址新增／修改入参，对应后端 domain/dto/AddressDTO.java
 */
export interface AddressBody {
  userId: number;
  receiver: string;
  phone: string;
  province?: string;
  city?: string;
  district?: string;
  detail: string;
  isDefault: boolean;
}

/**
 * 收货地址 相关接口
 */
export class AddressApi {

  static listByUser(userId: number): Promise<Address[]> {
    return HttpClient.get<Address[]>(`/api/addresses?userId=${userId}`);
  }

  static detail(id: number): Promise<Address> {
    return HttpClient.get<Address>(`/api/addresses/${id}`);
  }

  static create(body: AddressBody): Promise<Address> {
    return HttpClient.post<Address>('/api/addresses', body);
  }

  static update(id: number, body: AddressBody): Promise<Address> {
    return HttpClient.put<Address>(`/api/addresses/${id}`, body);
  }

  static remove(id: number, userId: number): Promise<boolean> {
    return HttpClient.remove(`/api/addresses/${id}?userId=${userId}`);
  }
}
