import { HttpClient } from './HttpClient';
import { MemberCard, MemberPlan, MemberSummary } from '../model/Member';

/**
 * 会员 相关接口
 *
 * 后端前缀 /api/member，四个端点分别对应：
 *   summary 会员概要 / plans 在售档位 / cards 已开通卡 / open 开通或续费
 */
export class MemberApi {

  /** 会员概要（昵称 / 会员号 / V金 / 卡券 / 余额 / 成就 + 生效卡） */
  static summary(userId: number): Promise<MemberSummary> {
    return HttpClient.get<MemberSummary>(`/api/member/summary?userId=${userId}`);
  }

  /**
   * 在售档位
   *
   * @param cardType GOD 大神卡 / COFFEE 咖啡卡；传空取全部
   */
  static plans(cardType: string): Promise<MemberPlan[]> {
    const query: string = cardType.length > 0 ? `?cardType=${cardType}` : '';
    return HttpClient.get<MemberPlan[]>(`/api/member/plans${query}`);
  }

  static cards(userId: number): Promise<MemberCard[]> {
    return HttpClient.get<MemberCard[]>(`/api/member/cards?userId=${userId}`);
  }

  /** 开通 / 续费，返回开通后的最新概要 */
  static open(userId: number, planCode: string): Promise<MemberSummary> {
    const body: MemberOpenBody = { userId: userId, planCode: planCode };
    return HttpClient.post<MemberSummary>('/api/member/cards', body);
  }
}

/** 开卡请求体，对应后端 domain/dto/MemberOpenDTO.java */
interface MemberOpenBody {
  userId: number;
  planCode: string;
}
