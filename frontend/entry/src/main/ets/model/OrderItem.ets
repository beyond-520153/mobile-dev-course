/**
 * 订单明细 —— 与后端 domain/vo/OrderItemVO.java 字段一一对应
 */
export interface OrderItem {
  id: number;
  orderId: number;
  productId: number;
  productName: string;
  productImage?: string;
  price: number;
  quantity: number;
  subtotal: number;
}
