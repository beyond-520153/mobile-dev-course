/**
 * 统一响应结构，与后端 common/result/Result.java 一一对应
 */
export interface ApiResult<T> {
  code: number;
  message: string;
  data: T;
}

/** 购物车汇总，对应后端 CartItemController.CartSummary */
export interface CartSummary {
  count: number;
  amount: number;
}
