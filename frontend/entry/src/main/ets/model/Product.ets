/**
 * 餐品 —— 与后端 domain/vo/ProductVO.java 字段一一对应
 *
 * image 字段存官方图相对路径（/images/products/xxx.gif|jpg|png），
 * 由后端静态资源提供；展示时由 components/ProductThumb.ets 补上服务端地址。
 */
export interface Product {
  id: number;
  categoryId: number;
  name: string;
  description?: string;
  price: number;
  /** 划线原价，等于 price 表示无折扣 */
  originPrice?: number;
  image?: string;
  stock: number;
  sortOrder: number;
  status: number;
}
