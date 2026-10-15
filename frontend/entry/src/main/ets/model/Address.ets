/**
 * 收货地址 —— 与后端 domain/vo/AddressVO.java 字段一一对应
 */
export interface Address {
  id: number;
  userId: number;
  receiver: string;
  phone: string;
  province?: string;
  city?: string;
  district?: string;
  detail: string;
  isDefault: boolean;
  /** 后端拼好的整串地址 */
  fullAddress: string;
}
