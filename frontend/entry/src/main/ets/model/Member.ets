/**
 * 会员 —— 与后端 domain/vo 里的三个出参一一对应
 */

/** 已开通的会员卡（MemberCardVO） */
export interface MemberCard {
  id: number;
  planId: number;
  cardType: string;
  cardName: string;
  cardNo: string;
  status: string;
  startAt: string;
  expireAt: string;
  /** 剩余天数，后端算好；已过期为 0 */
  remainDays: number;
}

/** 会员概要（MemberSummaryVO）：WOW 会员中心头部那一屏的数据 */
export interface MemberSummary {
  id: number;
  userId: number;
  memberNo: string;
  nickname?: string;
  /** 普通会员 / WOW会员 */
  level: string;
  vgold: number;
  couponCount: number;
  balance: number;
  achievement: number;
  hasCard: boolean;
  cards: MemberCard[];
  createdAt: string;
}

/** 会员卡档位（MemberPlanVO）：大神卡页的三张价格卡 */
export interface MemberPlan {
  id: number;
  code: string;
  /** GOD 大神卡 / COFFEE 咖啡卡 */
  cardType: string;
  name: string;
  months: number;
  price: number;
  originPrice: number;
  privilegeNum: number;
  days: number;
}
