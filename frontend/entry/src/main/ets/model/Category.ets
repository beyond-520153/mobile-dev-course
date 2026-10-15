import { Product } from './Product';

/**
 * 餐品分类 —— 与后端 domain/vo/CategoryVO.java 字段一一对应
 *
 * 后端已经把该分类下的在售餐品装进来了，点餐首页一次请求即可渲染。
 */
export interface Category {
  id: number;
  name: string;
  sortOrder: number;
  icon?: string;
  status: number;
  products: Product[];
}
