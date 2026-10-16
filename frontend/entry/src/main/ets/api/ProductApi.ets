import { HttpClient } from './HttpClient';
import { Category } from '../model/Category';
import { Product } from '../model/Product';

/**
 * 餐品分类新增／修改入参，对应后端 domain/dto/CategoryDTO.java
 */
export interface CategoryBody {
  name: string;
  sortOrder: number;
  icon?: string;
  status: number;
}

/**
 * 餐品新增／修改入参，对应后端 domain/dto/ProductDTO.java
 */
export interface ProductBody {
  categoryId: number;
  name: string;
  description?: string;
  price: number;
  originPrice?: number;
  image?: string;
  stock?: number;
  sortOrder?: number;
  status?: number;
}

/**
 * 餐品与分类 相关接口
 */
export class ProductApi {

  /** 点餐首页：分类 + 各自分类下在售餐品（后端一次返回，含 Redis 缓存） */
  static listCategories(): Promise<Category[]> {
    return HttpClient.get<Category[]>('/api/categories');
  }

  static categoryDetail(id: number): Promise<Category> {
    return HttpClient.get<Category>(`/api/categories/${id}`);
  }

  static createCategory(body: CategoryBody): Promise<Category> {
    return HttpClient.post<Category>('/api/categories', body);
  }

  static updateCategory(id: number, body: CategoryBody): Promise<Category> {
    return HttpClient.put<Category>(`/api/categories/${id}`, body);
  }

  static removeCategory(id: number): Promise<boolean> {
    return HttpClient.remove(`/api/categories/${id}`);
  }

  /**
   * 搜索餐品
   *
   * 后端按「餐品名 + 描述 + 所属分类名 + 拼音首字母」四路匹配，
   * 例如「咖啡」能命中整个咖啡分类、「YWJ」能命中原味鸡系列。
   *
   * @param keyword 关键词，必填
   */
  static search(keyword: string): Promise<Product[]> {
    return HttpClient.get<Product[]>(`/api/products/search?keyword=${encodeURIComponent(keyword)}`);
  }

  /**
   * 餐品列表
   *
   * @param categoryId 可选，按分类筛选
   * @param keyword    可选，按名称模糊搜索
   */
  static list(categoryId?: number, keyword?: string): Promise<Product[]> {
    const parts: string[] = [];
    if (categoryId !== undefined) {
      parts.push(`categoryId=${categoryId}`);
    }
    if (keyword !== undefined && keyword.length > 0) {
      parts.push(`keyword=${encodeURIComponent(keyword)}`);
    }
    const query = parts.length > 0 ? `?${parts.join('&')}` : '';
    return HttpClient.get<Product[]>(`/api/products${query}`);
  }

  static detail(id: number): Promise<Product> {
    return HttpClient.get<Product>(`/api/products/${id}`);
  }

  static create(body: ProductBody): Promise<Product> {
    return HttpClient.post<Product>('/api/products', body);
  }

  static update(id: number, body: ProductBody): Promise<Product> {
    return HttpClient.put<Product>(`/api/products/${id}`, body);
  }

  static remove(id: number): Promise<boolean> {
    return HttpClient.remove(`/api/products/${id}`);
  }
}
