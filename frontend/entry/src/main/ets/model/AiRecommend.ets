import { Product } from './Product';

/**
 * AI 点餐 —— 与后端 domain/vo/AiRecommendVO.java 一一对应
 *
 * 卡片里的 product 就是普通 Product，会员价字段（memberPriceText 等）
 * 由后端按当前登录用户现算，未登录时为空。
 */
export interface AiStore {
  name: string;
  address: string;
  distance: string;
  pickupType: string;
  /** 中文取餐方式，如「自取」 */
  pickupText: string;
}

export interface AiPick {
  /** 从 1 开始，对应「选1」「选2」 */
  index: number;
  label: string;
  product: Product;
  /** 模型给的一句话卖点，本地补位的卡片会填「门店热销款」 */
  reason: string;
  /** AI = 模型选的；FALLBACK = 模型没给或给了非法 id，本地补的 */
  source: string;
}

export interface AiRecommend {
  reply: string;
  /** true 表示这次是本地兜底推荐（模型超时/未配置），页面可提示但照常展示 */
  degraded?: boolean;
  degradeReason?: string;
  store: AiStore;
  items: AiPick[];
  model: string;
  costMs: number;
}
