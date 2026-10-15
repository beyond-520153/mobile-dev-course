import { OrderItem } from './OrderItem';

/**
 * 订单 —— 与后端 domain/vo/OrderVO.java 字段一一对应
 */
export interface Order {
  id: number;
  orderNo: string;
  userId: number;
  addressId?: number;
  /** PICKUP 到店自取 / DELIVERY 外送 */
  pickupType: string;
  pickupTypeText: string;
  totalAmount: number;
  payAmount: number;
  /** PENDING_PAYMENT / PAID / READY / COMPLETED / CANCELLED */
  status: string;
  statusText: string;
  remark?: string;
  pickupCode?: string;
  payTime?: string;
  createdAt: string;
  itemCount: number;
  items: OrderItem[];
}
