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

  /*
   * 会员价：后端只在「带了有效 token 且当前用户持卡」时返回，
   * 未登录 / 未持卡时这几个字段为 undefined，卡片上就不显示标签。
   */
  /** 单件可享的会员价 */
  memberPrice?: number;
  /** 卡名：大神卡 / 咖啡卡 */
  memberCardName?: string;
  /** 规则名，如「每日 1 杯指定咖啡 10 元」 */
  memberBenefit?: string;
  /** 拼好的展示文案，如「大神卡 ¥10.00」 */
  memberPriceText?: string;
}
