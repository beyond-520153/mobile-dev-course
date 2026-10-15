import { HttpClient } from './HttpClient';
import { CartItem } from '../model/CartItem';
import { CartSummary } from '../model/ApiResult';

/**
 * 加入购物车入参，对应后端 domain/dto/CartItemDTO.java
 */
export interface CartAddBody {
  userId: number;
  productId: number;
  quantity: number;
}

/**
 * 修改数量入参，对应后端 domain/dto/CartItemUpdateDTO.java
 * 数量传 0 等价于删除该条目。
 */
export interface CartUpdateBody {
  quantity: number;
}

/**
 * 购物车 相关接口
 */
export class CartApi {

  static list(userId: number): Promise<CartItem[]> {
    return HttpClient.get<CartItem[]>(`/api/cart-items?userId=${userId}`);
  }

  /** 件数 + 合计金额，底部购物车栏用 */
  static summary(userId: number): Promise<CartSummary> {
    return HttpClient.get<CartSummary>(`/api/cart-items/summary?userId=${userId}`);
  }

  static add(body: CartAddBody): Promise<CartItem> {
    return HttpClient.post<CartItem>('/api/cart-items', body);
  }

  static updateQuantity(id: number, quantity: number): Promise<CartItem> {
    const body: CartUpdateBody = { quantity: quantity };
    return HttpClient.put<CartItem>(`/api/cart-items/${id}`, body);
  }

  static remove(id: number, userId: number): Promise<boolean> {
    return HttpClient.remove(`/api/cart-items/${id}?userId=${userId}`);
  }

  static clear(userId: number): Promise<boolean> {
    return HttpClient.remove(`/api/cart-items?userId=${userId}`);
  }
}
