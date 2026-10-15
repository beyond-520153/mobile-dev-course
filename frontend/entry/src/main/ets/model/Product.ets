/**
 * 餐品 —— 与后端 domain/vo/ProductVO.java 字段一一对应
 *
 * image 字段联调期放的是 emoji 占位（后端种子数据里就是 emoji），
 * 以 http 开头时按图片渲染，否则按文字渲染。见 components/ProductThumb.ets
 */
export interface Product {
  id: number;
  categoryId: number;
  name: string;
  description?: string;
  price: number;
  image?: string;
  stock: number;
  sortOrder: number;
  status: number;
}
