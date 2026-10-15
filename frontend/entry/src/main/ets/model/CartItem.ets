/**
 * 购物车条目 —— 与后端 domain/vo/CartItemVO.java 字段一一对应
 */
export interface CartItem {
  /** 购物车条目主键，改数量/删除用它 */
  id: number;
  userId: number;
  productId: number;
  productName: string;
  productImage?: string;
  price: number;
  quantity: number;
  subtotal: number;
  stock?: number;
  productStatus?: number;
}
