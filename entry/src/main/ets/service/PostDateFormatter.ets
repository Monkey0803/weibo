export enum PostDateKind {
  RAW = 0,
  JUST_NOW = 1,
  MINUTES_AGO = 2,
  HOURS_AGO = 3,
  YESTERDAY = 4,
  MONTH_DAY = 5,
  YEAR_MONTH_DAY = 6,
  FULL = 7
}

export class PostDateDisplay {
  readonly kind: PostDateKind;
  readonly first: number;
  readonly second: number;
  readonly third: number;
  readonly fourth: number;
  readonly fifth: number;
  readonly raw: string;

  constructor(kind: PostDateKind, first: number = 0, second: number = 0, third: number = 0,
    fourth: number = 0, fifth: number = 0, raw: string = '') {
    this.kind = kind;
    this.first = first;
    this.second = second;
    this.third = third;
    this.fourth = fourth;
    this.fifth = fifth;
    this.raw = raw;
  }
}

export class PostDateFormatter {
  private static parse(value: string): Date | undefined {
    if (value.length === 0) {
      return undefined;
    }
    const normalized: string = value.replace(/([+-]\d{2})(\d{2})\s/, '$1:$2 ');
    const timestamp: number = Date.parse(normalized);
    if (!Number.isFinite(timestamp)) {
      return undefined;
    }
    return new Date(timestamp);
  }

  private static startOfDay(date: Date): number {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  }

  static friendly(value: string, nowMillis: number = Date.now()): PostDateDisplay {
    const date: Date | undefined = PostDateFormatter.parse(value);
    if (!date) {
      return new PostDateDisplay(PostDateKind.RAW, 0, 0, 0, 0, 0, value);
    }
    const elapsed: number = nowMillis - date.getTime();
    if (elapsed >= 0 && elapsed < 60000) {
      return new PostDateDisplay(PostDateKind.JUST_NOW);
    }
    if (elapsed >= 0 && elapsed < 3600000) {
      return new PostDateDisplay(PostDateKind.MINUTES_AGO, Math.max(1, Math.floor(elapsed / 60000)));
    }
    if (elapsed >= 0 && elapsed < 86400000) {
      return new PostDateDisplay(PostDateKind.HOURS_AGO, Math.max(1, Math.floor(elapsed / 3600000)));
    }
    const now: Date = new Date(nowMillis);
    const dayDifference: number = Math.floor((PostDateFormatter.startOfDay(now) -
      PostDateFormatter.startOfDay(date)) / 86400000);
    if (dayDifference === 1) {
      return new PostDateDisplay(PostDateKind.YESTERDAY);
    }
    if (date.getFullYear() === now.getFullYear()) {
      return new PostDateDisplay(PostDateKind.MONTH_DAY, date.getMonth() + 1, date.getDate());
    }
    return new PostDateDisplay(PostDateKind.YEAR_MONTH_DAY,
      date.getFullYear(), date.getMonth() + 1, date.getDate());
  }

  static full(value: string): PostDateDisplay {
    const date: Date | undefined = PostDateFormatter.parse(value);
    if (!date) {
      return new PostDateDisplay(PostDateKind.RAW, 0, 0, 0, 0, 0, value);
    }
    return new PostDateDisplay(PostDateKind.FULL, date.getFullYear(), date.getMonth() + 1,
      date.getDate(), date.getHours(), date.getMinutes());
  }
}
