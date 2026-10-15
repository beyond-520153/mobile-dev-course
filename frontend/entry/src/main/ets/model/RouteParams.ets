/**
 * 页面间传参用的类
 *
 * 不用匿名对象字面量：ArkTS 要求对象字面量必须对应一个显式声明的类型，
 * 而路由的 params 字段类型是宽泛的 Object，用类实例最稳妥。
 */
export class OrderDetailParams {

  orderId: number = 0;

  constructor(orderId: number) {
    this.orderId = orderId;
  }
}

/** 登录页传参：登录成功后要回到哪个页面 */
export class LoginParams {

  from: string = '';

  constructor(from: string) {
    this.from = from;
  }
}
