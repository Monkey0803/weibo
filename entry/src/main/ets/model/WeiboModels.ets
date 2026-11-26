export enum LoadState {
  IDLE = 0,
  LOADING = 1,
  READY = 2,
  EMPTY = 3,
  ERROR = 4
}

export enum FeedKind {
  FOLLOWING = 0,
  HOT = 1
}

export enum ApiFailureKind {
  NONE = 0,
  NO_COOKIE = 1,
  NETWORK = 2,
  HTTP_STATUS = 3,
  AUTH_EXPIRED = 4,
  API_REJECTED = 5,
  PARSE = 6
}

export class Result<T> {
  readonly success: boolean;
  readonly data?: T;
  readonly message: string;
  readonly authRequired: boolean;
  readonly failureKind: ApiFailureKind;
  readonly statusCode: number;

  constructor(success: boolean, message: string = '', data?: T, authRequired: boolean = false,
    failureKind: ApiFailureKind = ApiFailureKind.NONE, statusCode: number = 0) {
    this.success = success;
    this.message = message;
    this.data = data;
    this.authRequired = authRequired;
    this.failureKind = failureKind;
    this.statusCode = statusCode;
  }

  static ok<T>(data: T): Result<T> {
    return new Result<T>(true, '', data);
  }

  static fail<T>(message: string, authRequired: boolean = false,
    failureKind: ApiFailureKind = ApiFailureKind.API_REJECTED, statusCode: number = 0): Result<T> {
    return new Result<T>(false, message, undefined, authRequired, failureKind, statusCode);
  }
}

export class WeiboUser {
  id: string = '';
  name: string = '';
  avatarUrl: string = '';
  description: string = '';
  followersCount: number = 0;
  followingCount: number = 0;
  statusesCount: number = 0;
  verified: boolean = false;
}

export class WeiboMedia {
  imageUrls: string[] = [];
  videoUrl: string = '';
  videoPosterUrl: string = '';
}

export class WeiboPost {
  id: string = '';
  mid: string = '';
  user: WeiboUser = new WeiboUser();
  text: string = '';
  createdAt: string = '';
  source: string = '';
  repostsCount: number = 0;
  commentsCount: number = 0;
  likesCount: number = 0;
  liked: boolean = false;
  media: WeiboMedia = new WeiboMedia();
  repost?: WeiboPost;
}

export class WeiboComment {
  id: string = '';
  user: WeiboUser = new WeiboUser();
  text: string = '';
  createdAt: string = '';
  likesCount: number = 0;
}

export class PageResult<T> {
  readonly items: T[];
  readonly nextCursor: string;
  readonly hasMore: boolean;

  constructor(items: T[], nextCursor: string = '', hasMore: boolean = false) {
    this.items = items;
    this.nextCursor = nextCursor;
    this.hasMore = hasMore;
  }
}

export class PostRouteParam {
  readonly post: WeiboPost;

  constructor(post: WeiboPost) {
    this.post = post;
  }
}

export class UserRouteParam {
  readonly userId: string;
  readonly title: string;

  constructor(userId: string, title: string) {
    this.userId = userId;
    this.title = title;
  }
}

export class VideoRouteParam {
  readonly videoUrl: string;
  readonly posterUrl: string;

  constructor(videoUrl: string, posterUrl: string) {
    this.videoUrl = videoUrl;
    this.posterUrl = posterUrl;
  }
}

export class ImagePreviewRouteParam {
  readonly imageUrls: string[];
  readonly initialIndex: number;

  constructor(imageUrls: string[], initialIndex: number) {
    this.imageUrls = imageUrls;
    if (initialIndex < 0 || initialIndex >= imageUrls.length) {
      this.initialIndex = 0;
    } else {
      this.initialIndex = initialIndex;
    }
  }
}

export class SessionInfo {
  readonly loggedIn: boolean;
  readonly userId: string;

  constructor(loggedIn: boolean, userId: string = '') {
    this.loggedIn = loggedIn;
    this.userId = userId;
  }
}

export class SessionSnapshot {
  readonly hasCandidateCookie: boolean;
  readonly cookieNames: string[];
  readonly cookieDomains: string[];

  constructor(hasCandidateCookie: boolean, cookieNames: string[] = [], cookieDomains: string[] = []) {
    this.hasCandidateCookie = hasCandidateCookie;
    this.cookieNames = cookieNames;
    this.cookieDomains = cookieDomains;
  }
}
