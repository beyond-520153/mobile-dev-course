/**
 * 日期时间格式化工具
 *
 * 后端返回的是 OffsetDateTime，序列化成 ISO-8601 字符串，如
 * "2026-10-15T20:56:30.123+08:00"。这里统一转成界面要展示的样式。
 */
export class DateUtil {

  private static pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  /** 2026-10-15 20:56 */
  static formatDateTime(iso?: string): string {
    const d = DateUtil.parse(iso);
    if (d === null) {
      return iso === undefined ? '' : iso;
    }
    return `${d.getFullYear()}-${DateUtil.pad(d.getMonth() + 1)}-${DateUtil.pad(d.getDate())} `
      + `${DateUtil.pad(d.getHours())}:${DateUtil.pad(d.getMinutes())}`;
  }

  /** 10-15 20:56 */
  static formatShort(iso?: string): string {
    const d = DateUtil.parse(iso);
    if (d === null) {
      return iso === undefined ? '' : iso;
    }
    return `${DateUtil.pad(d.getMonth() + 1)}-${DateUtil.pad(d.getDate())} `
      + `${DateUtil.pad(d.getHours())}:${DateUtil.pad(d.getMinutes())}`;
  }

  private static parse(iso?: string): Date | null {
    if (iso === undefined || iso.length === 0) {
      return null;
    }
    const d = new Date(DateUtil.normalize(iso));
    if (Number.isNaN(d.getTime())) {
      return null;
    }
    return d;
  }

  /**
   * 把小数秒截断到 3 位。
   *
   * ECMAScript 的日期字符串格式只认 3 位毫秒，而后端（Java）可能带 6~9 位
   * 微秒/纳秒，例如 2026-10-15T13:10:53.369111Z。V8 能宽容解析，但换个
   * 引擎就可能返回 Invalid Date，所以这里主动规整一次。
   */
  private static normalize(iso: string): string {
    const dot = iso.indexOf('.');
    if (dot < 0) {
      return iso;
    }
    let end = dot + 1;
    while (end < iso.length) {
      const code = iso.charCodeAt(end);
      if (code < 48 || code > 57) {
        break;
      }
      end++;
    }
    const digits = end - dot - 1;
    let frac = iso.substring(dot + 1, end);
    if (digits > 3) {
      frac = frac.substring(0, 3);
    }
    return iso.substring(0, dot + 1) + frac + iso.substring(end);
  }
}
