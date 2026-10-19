import { HttpClient } from './HttpClient';
import { AiRecommend, ChatTurn } from '../model/AiRecommend';

/**
 * AI 点餐入参，对应后端 domain/dto/AiChatDTO.java
 */
export interface AiChatBody {
  /** 用户说的话；空串表示「刚进店」 */
  message: string;
  /** PICKUP / DELIVERY / DRIVE */
  pickupType: string;
  /** 要几张卡片，后端会裁到 1~9 */
  count: number;
  /** 前几轮对话，后端只留最近 6 条、role 只认 user/assistant */
  history: ChatTurn[];
}

/**
 * AI 点餐接口
 *
 * 后端拿到的是真实菜单，模型只负责「挑哪几样 + 说一句话」，
 * 图片、价格、库存、会员价全部由后端回表补齐，所以前端拿到的
 * 每一张卡都能直接下单。
 */
export class AiApi {

  /**
   * 要一组推荐
   *
   * @param message    用户的话，空串表示首屏；「换一换」也会原样传下去
   * @param pickupType 取餐方式，只影响话术
   * @param history    之前的对话，用于接上下文；首屏传空数组
   */
  static recommend(message: string, pickupType: string, history: ChatTurn[]): Promise<AiRecommend> {
    const body: AiChatBody = {
      message: message,
      pickupType: pickupType,
      count: 6,
      history: history
    };
    // 模型出结果通常 2~4 秒，留 35 秒余量；比 HttpClient 默认的 10 秒宽
    return HttpClient.post<AiRecommend>('/api/ai/recommend', body, 35000);
  }
}
