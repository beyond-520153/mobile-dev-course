import { HttpClient } from './HttpClient';
import { Order } from '../model/Order';
import { OrderQuote } from '../model/OrderQuote';

/**
 * 下单入参，对应后端 domain/dto/OrderCreateDTO.java
 *
 * 下单的餐品来源是「该用户当前的购物车」，不在这里传明细，
 * 避免前端算价与服务端算价不一致。
 */
export interface OrderCreateBody {
  userId: number;
  /** 外送必填；到店自取传 0 或不传 */
  addressId?: number;
  /** PICKUP 到店自取 / DELIVERY 外送 */
  pickupType: string;
  remark?: string;
}

/**
 * 订单 相关接口
 */
export class OrderApi {

  static listByUser(userId: number): Promise<Order[]> {
    return HttpClient.get<Order[]>(`/api/orders?userId=${userId}`);
  }

  static listAll(): Promise<Order[]> {
    return HttpClient.get<Order[]>('/api/orders');
  }

  static detail(id: number): Promise<Order> {
    return HttpClient.get<Order>(`/api/orders/${id}`);
  }

  /**
   * 结算试算：套用会员卡权益算应付金额
   *
   * 只读接口，不扣库存、不扣权益次数，结算页可以放心反复调。
   */
  static quote(userId: number, pickupType: string): Promise<OrderQuote> {
    return HttpClient.get<OrderQuote>(`/api/orders/quote?userId=${userId}&pickupType=${pickupType}`);
  }

  static create(body: OrderCreateBody): Promise<Order> {
    return HttpClient.post<Order>('/api/orders', body);
  }

  /** 支付：成功后返回带取餐码的订单（无请求体，body 省略以避开 ArkTS 无类型对象字面量限制） */
  static pay(id: number): Promise<Order> {
    return HttpClient.post<Order>(`/api/orders/${id}/pay`);
  }

  static cancel(id: number): Promise<Order> {
    return HttpClient.post<Order>(`/api/orders/${id}/cancel`);
  }

  static remove(id: number): Promise<boolean> {
    return HttpClient.remove(`/api/orders/${id}`);
  }
}
