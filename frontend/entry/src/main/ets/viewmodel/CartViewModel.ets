import { CartApi } from '../api/CartApi';
import { CartSummary } from '../model/ApiResult';

/**
 * 购物车状态管理（MVVM 的 VM 层）
 *
 * 跨页面共享靠 AppStorage：
 *   userId      当前登录用户（0 表示未登录）
 *   cartCount   购物车件数，底部购物车栏角标
 *   cartAmount  购物车合计金额
 *
 * 页面里用 @StorageLink('cartCount') 就能自动跟着变，不用自己传参。
 */
export class CartViewModel {

  static readonly KEY_USER_ID: string = 'userId';
  static readonly KEY_COUNT: string = 'cartCount';
  static readonly KEY_AMOUNT: string = 'cartAmount';

  /** 拉一次后端汇总并写进 AppStorage；网络不通时静默失败，不打断页面 */
  static async refresh(userId: number): Promise<void> {
    if (userId <= 0) {
      CartViewModel.reset();
      return;
    }
    try {
      const summary: CartSummary = await CartApi.summary(userId);
      AppStorage.setOrCreate(CartViewModel.KEY_COUNT, summary.count);
      AppStorage.setOrCreate(CartViewModel.KEY_AMOUNT, summary.amount);
    } catch (err) {
      // 后端没起或者网断了：保持上一次的数字，页面自己会提示错误
      console.error(`刷新购物车汇总失败: ${err}`);
    }
  }

  static reset(): void {
    AppStorage.setOrCreate(CartViewModel.KEY_COUNT, 0);
    AppStorage.setOrCreate(CartViewModel.KEY_AMOUNT, 0);
  }

  /** 当前登录用户 id，未登录返回 0 */
  static currentUserId(): number {
    const value: number | undefined = AppStorage.get<number>(CartViewModel.KEY_USER_ID);
    return value === undefined ? 0 : value;
  }

  static setCurrentUserId(id: number): void {
    AppStorage.setOrCreate(CartViewModel.KEY_USER_ID, id);
  }

  static clearUser(): void {
    CartViewModel.setCurrentUserId(0);
    AppStorage.setOrCreate<string>('token', '');
    CartViewModel.reset();
  }
}
