import { CartItem } from './CartItem';

/**
 * 单条优惠明细 —— 对应后端 domain/vo/DiscountLineVO.java
 */
export interface DiscountLine {
  code: string;
  name: string;
  /** PERCENT_OFF / AMOUNT_OFF / FIXED_PRICE / FREE_DELIVERY */
  benefitType: string;
  description?: string;
  /** 本条优惠减掉多少钱 */
  discountAmount: number;
  /** 命中的餐品，如「拿铁 ×1」 */
  itemText?: string;
  /** true 表示抵的是外送费 */
  onDeliveryFee: boolean;
}

/**
 * 结算试算结果 —— 对应后端 domain/vo/OrderQuoteVO.java
 *
 * 下单接口返回的金额与这里同源（后端同一个方法算），
 * 所以结算页显示的应付金额就是最终扣款金额。
 */
export interface OrderQuote {
  userId: number;
  pickupType: string;
  pickupTypeText: string;
  items: CartItem[];
  itemCount: number;
  goodsAmount: number;
  deliveryFee: number;
  discountAmount: number;
  payAmount: number;
  /** 是否大神卡持有者 */
  godCard: boolean;
  godCardName?: string;
  discounts: DiscountLine[];
  /** 汇总文案，如「大神卡 季卡已省 ¥9.00」 */
  benefitText?: string;
  /** 没有优惠时的提示 */
  hint?: string;
}
