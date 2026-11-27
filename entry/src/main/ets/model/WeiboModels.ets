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

export enum SearchKind {
  COMPREHENSIVE = 1,
  REALTIME = 61,
  HOT = 60,
  VIDEO = 64
}

export enum SocialListKind {
  FOLLOWING = 0,
  FOLLOWERS = 1
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

export enum CommentLoadMode {
  HOT = 0,
  BASIC = 1
}

export enum SocialTextEntityKind {
  TOPIC = 0,
  MENTION = 1,
  LINK = 2
}

export enum WeiboMediaKind {
  NONE = 0,
  IMAGE = 1,
  VIDEO = 2,
  LIVE = 3
}

export enum WeiboLiveState {
  UNKNOWN = 0,
  ACTIVE = 1,
  ENDED = 2
}

export class SocialTextEntity {
  readonly kind: SocialTextEntityKind;
  readonly start: number;
  readonly length: number;
  readonly displayText: string;
  readonly query: string;
  readonly userId: string;
  readonly url: string;

  constructor(kind: SocialTextEntityKind, start: number, length: number, displayText: string,
    query: string, userId: string = '', url: string = '') {
    this.kind = kind;
    this.start = start;
    this.length = length;
    this.displayText = displayText;
    this.query = query;
    this.userId = userId;
    this.url = url;
  }
}

export class SocialTextContent {
  readonly text: string;
  readonly entities: SocialTextEntity[];

  constructor(text: string = '', entities: SocialTextEntity[] = []) {
    this.text = text;
    this.entities = entities;
  }
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
  descriptionEntities: SocialTextEntity[] = [];
  followersCount: number = 0;
  followingCount: number = 0;
  statusesCount: number = 0;
  verified: boolean = false;
  following: boolean = false;
  followedBy: boolean = false;
  location: string = '';
  verifiedReason: string = '';
  ipLocation: string = '';
  birthday: string = '';
  joinedAt: string = '';
}

export class WeiboMedia {
  kind: WeiboMediaKind = WeiboMediaKind.NONE;
  imageUrls: string[] = [];
  videoUrl: string = '';
  videoPosterUrl: string = '';
  pageUrl: string = '';
  pageTitle: string = '';
  liveState: WeiboLiveState = WeiboLiveState.UNKNOWN;
}

export class WeiboPost {
  id: string = '';
  mid: string = '';
  user: WeiboUser = new WeiboUser();
  text: string = '';
  textEntities: SocialTextEntity[] = [];
  createdAt: string = '';
  source: string = '';
  repostsCount: number = 0;
  commentsCount: number = 0;
  likesCount: number = 0;
  liked: boolean = false;
  isLongText: boolean = false;
  fullTextUnavailable: boolean = false;
  favorited: boolean = false;
  media: WeiboMedia = new WeiboMedia();
  repost?: WeiboPost;
}

export class WeiboComment {
  id: string = '';
  user: WeiboUser = new WeiboUser();
  text: string = '';
  textEntities: SocialTextEntity[] = [];
  createdAt: string = '';
  likesCount: number = 0;
  replyCount: number = 0;
  replies: WeiboComment[] = [];
  repliesLoaded: boolean = false;
  repliesLoading: boolean = false;
  repliesHasMore: boolean = false;
  repliesCursor: string = '';
}

export class WeiboHotTopic {
  word: string = '';
  heat: number = 0;
  label: string = '';
  rank: number = 0;
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

export class CommentPageResult {
  readonly items: WeiboComment[];
  readonly nextCursor: string;
  readonly hasMore: boolean;
  readonly mode: CommentLoadMode;

  constructor(page: PageResult<WeiboComment>, mode: CommentLoadMode) {
    this.items = page.items;
    this.nextCursor = page.nextCursor;
    this.hasMore = page.hasMore;
    this.mode = mode;
  }
}

export class PostRouteParam {
  readonly post: WeiboPost;
  readonly focusComments: boolean;

  constructor(post: WeiboPost, focusComments: boolean = false) {
    this.post = post;
    this.focusComments = focusComments;
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

export class SocialListRouteParam {
  readonly userId: string;
  readonly kind: SocialListKind;
  readonly title: ResourceStr;

  constructor(userId: string, kind: SocialListKind, title: ResourceStr) {
    this.userId = userId;
    this.kind = kind;
    this.title = title;
  }
}

export class RepostListRouteParam {
  readonly postId: string;

  constructor(postId: string) {
    this.postId = postId;
  }
}

export class EntitySearchRouteParam {
  readonly query: string;
  readonly title: string;

  constructor(query: string, title: string) {
    this.query = query;
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
