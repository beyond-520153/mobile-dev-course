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
  /** 外送费（到店自取为 0） */
  deliveryFee: number;
  /** 会员卡权益优惠合计 */
  discountAmount: number;
  /** 实付 = totalAmount + deliveryFee - discountAmount */
  payAmount: number;
  /** 优惠文案，如「每日 1 杯咖啡 10 元 -9.00（拿铁 ×1）」 */
  benefitDetail?: string;
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
