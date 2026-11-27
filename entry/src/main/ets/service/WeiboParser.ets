import {
  PageResult,
  SessionInfo,
  SocialTextContent,
  WeiboComment,
  WeiboHotTopic,
  WeiboLiveState,
  WeiboMedia,
  WeiboMediaKind,
  WeiboPost,
  WeiboUser
} from '../model/WeiboModels';
import { SocialTextParser } from './SocialTextParser';

interface ApiUrls {
  mp4_720p_mp4?: string;
  mp4_hd_mp4?: string;
  mp4_ld_mp4?: string;
  stream_url_hd?: string;
  stream_url?: string;
  is_living?: boolean;
  live_status?: string | number;
  live_id?: string;
  h5_url?: string;
}

interface ApiPageInfo {
  media_info?: ApiUrls;
  page_pic?: ApiPicture;
  type?: string;
  object_type?: string | number;
  page_url?: string;
  page_title?: string;
  content1?: string;
  content2?: string;
  object_id?: string;
}

interface ApiPicture {
  url?: string;
  large?: ApiPicture;
}

interface ApiUser {
  id?: number;
  idstr?: string;
  screen_name?: string;
  profile_image_url?: string;
  avatar_hd?: string;
  description?: string;
  followers_count?: number;
  follow_count?: number;
  friends_count?: number;
  statuses_count?: number;
  verified?: boolean;
  following?: boolean;
  follow_me?: boolean;
  location?: string;
  verified_reason?: string;
  ip_location?: string;
  birthday?: string;
  created_at?: string;
}

interface ApiStatus {
  id?: number;
  idstr?: string;
  mid?: string;
  text?: string;
  text_raw?: string;
  created_at?: string;
  source?: string;
  reposts_count?: number;
  comments_count?: number;
  attitudes_count?: number;
  liked?: boolean;
  favorited?: boolean;
  isLongText?: boolean;
  textLength?: number;
  longText?: ApiLongTextData;
  user?: ApiUser;
  pics?: ApiPicture[];
  pic_ids?: string[];
  page_info?: ApiPageInfo;
  retweeted_status?: ApiStatus;
}

interface ApiComment {
  id?: number;
  idstr?: string;
  text?: string;
  text_raw?: string;
  created_at?: string;
  like_counts?: number;
  like_count?: number;
  total_number?: number;
  comments?: ApiComment[];
  user?: ApiUser;
}

interface ApiCardGroup {
  mblog?: ApiStatus;
  user?: ApiUser;
  card_group?: ApiCardGroup[];
}

interface ApiPageInfoContainer {
  page?: number;
  total?: number;
}

interface ApiData {
  statuses?: ApiStatus[];
  cards?: ApiCardGroup[];
  data?: ApiStatus[];
  comments?: ApiComment[];
  max_id?: number;
  max_id_str?: string;
  userInfo?: ApiUser;
  pageInfo?: ApiPageInfoContainer;
  login?: boolean;
  uid?: string | number;
  users?: ApiUser[];
  list?: ApiStatus[];
  realtime?: ApiHotTopic[];
  user?: ApiUser;
  status?: ApiStatus;
  comment?: ApiComment;
  location?: string;
  verified_reason?: string;
  ip_location?: string;
  birthday?: string;
  created_at?: string;
}

interface ApiEnvelope {
  ok?: number;
  msg?: string;
  message?: string;
  login?: boolean;
  uid?: string | number;
  data?: ApiData;
  statuses?: ApiStatus[];
  users?: ApiUser[];
  max_id?: number;
  max_id_str?: string;
}

interface ApiStatusArrayEnvelope {
  data?: ApiStatus[];
  max_id?: number;
  max_id_str?: string;
}

interface ApiHotTopic {
  word?: string;
  num?: number;
  icon_desc?: string;
  rank?: number;
}

interface ApiStatusEnvelope {
  data?: ApiStatus;
}

interface ApiLongTextData {
  longTextContent?: string;
}

interface ApiLongTextEnvelope {
  data?: ApiLongTextData;
}

interface ApiCommentData {
  data?: ApiComment[];
  comments?: ApiComment[];
  comment?: ApiComment;
  max_id?: number;
  max_id_str?: string;
}

interface ApiCommentEnvelope {
  data?: ApiCommentData;
}

interface ApiDirectCommentEnvelope {
  data?: ApiComment;
}

interface ApiBasicCommentEnvelope {
  data?: ApiComment[];
}

export class WeiboParser {
  static parseSession(content: string): SessionInfo {
    const envelope: ApiEnvelope = JSON.parse(content) as ApiEnvelope;
    const rawUserId: string | number = envelope.uid ?? envelope.data?.uid ?? '';
    const userId: string = typeof rawUserId === 'number' ? rawUserId.toString() : rawUserId;
    return new SessionInfo(envelope.login ?? envelope.data?.login ?? false, userId);
  }
  static parsePosts(content: string, currentPage: number): PageResult<WeiboPost> {
    const envelope: ApiEnvelope = JSON.parse(content) as ApiEnvelope;
    const arrayEnvelope: ApiStatusArrayEnvelope = JSON.parse(content) as ApiStatusArrayEnvelope;
    const rawItems: ApiStatus[] = [];
    if (envelope.data?.statuses) {
      rawItems.push(...envelope.data.statuses);
    } else if (envelope.statuses) {
      rawItems.push(...envelope.statuses);
    } else if (envelope.data?.data) {
      rawItems.push(...envelope.data.data);
    } else if (envelope.data?.list) {
      rawItems.push(...envelope.data.list);
    } else if (arrayEnvelope.data instanceof Array) {
      arrayEnvelope.data.forEach((item: ApiStatus) => rawItems.push(item));
    }
    WeiboParser.collectCardPosts(envelope.data?.cards ?? [], rawItems);
    const posts: WeiboPost[] = WeiboParser.deduplicate(
      rawItems.map((item: ApiStatus) => WeiboParser.toPost(item)));
    const cursor: string = envelope.data?.max_id_str ?? arrayEnvelope.max_id_str ??
      (envelope.data?.max_id?.toString() ?? arrayEnvelope.max_id?.toString() ?? '');
    const total: number = envelope.data?.pageInfo?.total ?? 0;
    const hasMore: boolean = cursor.length > 0 && cursor !== '0' || posts.length > 0 && (total === 0 || currentPage * 10 < total);
    return new PageResult<WeiboPost>(posts, cursor, hasMore);
  }

  static parseFollowingPosts(content: string): PageResult<WeiboPost> {
    const page: PageResult<WeiboPost> = WeiboParser.parsePosts(content, 1);
    const hasMore: boolean = page.nextCursor.length > 0 && page.nextCursor !== '0';
    return new PageResult<WeiboPost>(page.items, hasMore ? page.nextCursor : '', hasMore);
  }

  static parsePost(content: string): WeiboPost {
    const status: ApiStatus = JSON.parse(content) as ApiStatus;
    if (status.idstr || status.id) {
      return WeiboParser.toPost(status);
    }
    const envelope: ApiStatusEnvelope = JSON.parse(content) as ApiStatusEnvelope;
    const emptyStatus: ApiStatus = {};
    return WeiboParser.toPost(envelope.data ?? emptyStatus);
  }

  static parseLongText(content: string): string {
    return WeiboParser.parseLongTextContent(content).text;
  }

  static parseLongTextContent(content: string): SocialTextContent {
    const envelope: ApiLongTextEnvelope = JSON.parse(content) as ApiLongTextEnvelope;
    const htmlText: string = envelope.data?.longTextContent ?? '';
    return SocialTextParser.parse('', htmlText);
  }

  static parseEmbeddedLongTextContent(content: string, postId: string): SocialTextContent {
    const directStatus: ApiStatus = JSON.parse(content) as ApiStatus;
    const envelope: ApiStatusEnvelope = JSON.parse(content) as ApiStatusEnvelope;
    const emptyStatus: ApiStatus = {};
    const rootStatus: ApiStatus = directStatus.idstr || directStatus.id ? directStatus :
      (envelope.data ?? emptyStatus);
    return SocialTextParser.parse('', WeiboParser.embeddedLongText(rootStatus, postId));
  }

  static parseComments(content: string): PageResult<WeiboComment> {
    const envelope: ApiCommentEnvelope = JSON.parse(content) as ApiCommentEnvelope;
    const comments: ApiComment[] = envelope.data?.comments ?? envelope.data?.data ?? [];
    const items: WeiboComment[] = comments.map((item: ApiComment) => WeiboParser.toComment(item));
    const cursor: string = envelope.data?.max_id_str ?? (envelope.data?.max_id?.toString() ?? '');
    return new PageResult<WeiboComment>(items, cursor, cursor.length > 0 && cursor !== '0');
  }

  static parseCommentReplies(content: string): PageResult<WeiboComment> {
    const envelope: ApiCommentEnvelope = JSON.parse(content) as ApiCommentEnvelope;
    const comments: ApiComment[] = envelope.data?.data ?? envelope.data?.comments ?? [];
    const items: WeiboComment[] = comments.map((item: ApiComment) => WeiboParser.toComment(item));
    const cursor: string = envelope.data?.max_id_str ?? (envelope.data?.max_id?.toString() ?? '');
    return new PageResult<WeiboComment>(items, cursor, cursor.length > 0 && cursor !== '0');
  }

  static parseBasicComments(content: string, currentPage: number): PageResult<WeiboComment> {
    const directEnvelope: ApiBasicCommentEnvelope = JSON.parse(content) as ApiBasicCommentEnvelope;
    const nestedEnvelope: ApiCommentEnvelope = JSON.parse(content) as ApiCommentEnvelope;
    let comments: ApiComment[] = [];
    if (Array.isArray(directEnvelope.data)) {
      comments = directEnvelope.data;
    } else {
      comments = nestedEnvelope.data?.data ?? nestedEnvelope.data?.comments ?? [];
    }
    const items: WeiboComment[] = comments.map((item: ApiComment) => WeiboParser.toComment(item));
    const hasMore: boolean = items.length > 0;
    const nextPage: string = hasMore ? (currentPage + 1).toString() : '';
    return new PageResult<WeiboComment>(items, nextPage, hasMore);
  }

  static parseUsers(content: string, currentPage: number): PageResult<WeiboUser> {
    const envelope: ApiEnvelope = JSON.parse(content) as ApiEnvelope;
    const users: ApiUser[] = envelope.users ?? envelope.data?.users ?? [];
    const items: WeiboUser[] = users.map((item: ApiUser) => WeiboParser.toUser(item));
    return new PageResult<WeiboUser>(items, '', items.length >= 20);
  }

  static parseHotTopics(content: string): WeiboHotTopic[] {
    const envelope: ApiEnvelope = JSON.parse(content) as ApiEnvelope;
    const raw: ApiHotTopic[] = envelope.data?.realtime ?? [];
    const topics: WeiboHotTopic[] = [];
    raw.forEach((item: ApiHotTopic, index: number) => {
      if ((item.word ?? '').length > 0) {
        const topic: WeiboHotTopic = new WeiboHotTopic();
        topic.word = item.word ?? '';
        topic.heat = item.num ?? 0;
        topic.label = item.icon_desc ?? '';
        topic.rank = item.rank ?? index + 1;
        topics.push(topic);
      }
    });
    return topics;
  }

  static parseCreatedPost(content: string): WeiboPost {
    const envelope: ApiEnvelope = JSON.parse(content) as ApiEnvelope;
    const directEnvelope: ApiStatusEnvelope = JSON.parse(content) as ApiStatusEnvelope;
    const empty: ApiStatus = {};
    let status: ApiStatus = envelope.data?.status ?? empty;
    const statuses: ApiStatus[] = envelope.data?.statuses ?? [];
    const data: ApiStatus[] = envelope.data?.data ?? [];
    if (!status.id && statuses.length > 0) {
      status = statuses[0];
    }
    if (!status.id && data.length > 0) {
      status = data[0];
    }
    if (!status.id && (directEnvelope.data?.id || directEnvelope.data?.idstr)) {
      status = directEnvelope.data ?? empty;
    }
    return WeiboParser.toPost(status);
  }

  static parseCreatedComment(content: string): WeiboComment {
    const envelope: ApiCommentEnvelope = JSON.parse(content) as ApiCommentEnvelope;
    const directEnvelope: ApiDirectCommentEnvelope = JSON.parse(content) as ApiDirectCommentEnvelope;
    const empty: ApiComment = {};
    let comment: ApiComment = envelope.data?.comment ?? empty;
    const comments: ApiComment[] = envelope.data?.comments ?? [];
    const data: ApiComment[] = envelope.data?.data ?? [];
    if (!comment.id && comments.length > 0) {
      comment = comments[0];
    }
    if (!comment.id && data.length > 0) {
      comment = data[0];
    }
    if (!comment.id && (directEnvelope.data?.id || directEnvelope.data?.idstr)) {
      comment = directEnvelope.data ?? empty;
    }
    return WeiboParser.toComment(comment);
  }

  static mergeUserDetail(user: WeiboUser, content: string): WeiboUser {
    const envelope: ApiEnvelope = JSON.parse(content) as ApiEnvelope;
    const nested: ApiUser = envelope.data?.user ?? envelope.data?.userInfo ?? {};
    const detail: ApiUser = {
      location: nested.location ?? envelope.data?.location,
      verified_reason: nested.verified_reason ?? envelope.data?.verified_reason,
      ip_location: nested.ip_location ?? envelope.data?.ip_location,
      birthday: nested.birthday ?? envelope.data?.birthday,
      created_at: nested.created_at ?? envelope.data?.created_at
    };
    user.location = detail.location ?? user.location;
    user.verifiedReason = detail.verified_reason ?? user.verifiedReason;
    user.ipLocation = detail.ip_location ?? user.ipLocation;
    user.birthday = detail.birthday ?? user.birthday;
    user.joinedAt = detail.created_at ?? user.joinedAt;
    return user;
  }

  static parseUser(content: string): WeiboUser {
    const envelope: ApiEnvelope = JSON.parse(content) as ApiEnvelope;
    const emptyUser: ApiUser = {};
    return WeiboParser.toUser(envelope.data?.userInfo ?? emptyUser);
  }

  static isSuccessfulMutation(content: string): boolean {
    const envelope: ApiEnvelope = JSON.parse(content) as ApiEnvelope;
    return envelope.ok === 1;
  }

  private static collectCardPosts(cards: ApiCardGroup[], target: ApiStatus[]): void {
    cards.forEach((card: ApiCardGroup) => {
      if (card.mblog) {
        target.push(card.mblog);
      }
      if (card.card_group) {
        WeiboParser.collectCardPosts(card.card_group, target);
      }
    });
  }

  private static deduplicate(posts: WeiboPost[]): WeiboPost[] {
    const result: WeiboPost[] = [];
    const ids: Set<string> = new Set<string>();
    posts.forEach((post: WeiboPost) => {
      if (post.id.length > 0 && !ids.has(post.id)) {
        ids.add(post.id);
        result.push(post);
      }
    });
    return result;
  }

  private static toPost(raw: ApiStatus): WeiboPost {
    const post: WeiboPost = new WeiboPost();
    post.id = raw.idstr ?? raw.id?.toString() ?? '';
    post.mid = raw.mid ?? post.id;
    const emptyUser: ApiUser = {};
    post.user = WeiboParser.toUser(raw.user ?? emptyUser);
    const postContent: SocialTextContent = SocialTextParser.parse(raw.text_raw ?? '', raw.text ?? '');
    post.text = postContent.text;
    post.textEntities = postContent.entities;
    post.createdAt = raw.created_at ?? '';
    post.source = WeiboParser.cleanText(raw.source ?? '');
    post.repostsCount = raw.reposts_count ?? 0;
    post.commentsCount = raw.comments_count ?? 0;
    post.likesCount = raw.attitudes_count ?? 0;
    post.liked = raw.liked ?? false;
    post.favorited = raw.favorited ?? false;
    post.isLongText = raw.isLongText === true ||
      WeiboParser.hasFullTextAnchor(raw.text ?? '', post.id) ||
      WeiboParser.hasTruncatedText(raw.textLength ?? 0, post.text.length);
    post.media = WeiboParser.toMedia(raw);
    if (raw.retweeted_status) {
      post.repost = WeiboParser.toPost(raw.retweeted_status);
    }
    return post;
  }

  private static hasFullTextAnchor(htmlText: string, postId: string): boolean {
    if (htmlText.length === 0 || postId.length === 0) {
      return false;
    }
    const anchorPattern: RegExp = /<a\b[^>]*href\s*=\s*(?:"([^"]*)"|'([^']*)')[^>]*>([\s\S]*?)<\/a>/gi;
    let match: RegExpExecArray | null = anchorPattern.exec(htmlText);
    while (match !== null) {
      const href: string = (match[1] ?? match[2] ?? '').replace(/&amp;/gi, '&');
      const label: string = WeiboParser.cleanText(match[3] ?? '').trim();
      const statusPath: string = '/status/' + postId;
      const detailPath: string = '/detail/' + postId;
      if ((label === '全文' || label === '查看全文') &&
        (href.indexOf(statusPath) >= 0 || href.indexOf(detailPath) >= 0)) {
        return true;
      }
      match = anchorPattern.exec(htmlText);
    }
    return false;
  }

  private static hasTruncatedText(textLength: number, displayLength: number): boolean {
    return textLength > 280 && textLength > displayLength * 2 + 20;
  }

  private static embeddedLongText(raw: ApiStatus, postId: string): string {
    const currentId: string = raw.idstr ?? raw.id?.toString() ?? '';
    if (currentId === postId) {
      return raw.longText?.longTextContent ?? '';
    }
    if (raw.retweeted_status) {
      return WeiboParser.embeddedLongText(raw.retweeted_status, postId);
    }
    return '';
  }

  private static toUser(raw: ApiUser): WeiboUser {
    const user: WeiboUser = new WeiboUser();
    user.id = raw.idstr ?? raw.id?.toString() ?? '';
    user.name = raw.screen_name ?? '';
    user.avatarUrl = raw.avatar_hd ?? raw.profile_image_url ?? '';
    const description: SocialTextContent = SocialTextParser.parse(raw.description ?? '');
    user.description = description.text;
    user.descriptionEntities = description.entities;
    user.followersCount = raw.followers_count ?? 0;
    user.followingCount = raw.follow_count ?? raw.friends_count ?? 0;
    user.statusesCount = raw.statuses_count ?? 0;
    user.verified = raw.verified ?? false;
    user.following = raw.following ?? false;
    user.followedBy = raw.follow_me ?? false;
    user.location = raw.location ?? '';
    user.verifiedReason = raw.verified_reason ?? '';
    user.ipLocation = raw.ip_location ?? '';
    user.birthday = raw.birthday ?? '';
    user.joinedAt = raw.created_at ?? '';
    return user;
  }

  private static toMedia(raw: ApiStatus): WeiboMedia {
    const media: WeiboMedia = new WeiboMedia();
    const pictures: ApiPicture[] = raw.pics ?? [];
    pictures.forEach((picture: ApiPicture) => {
      const url: string = picture.large?.url ?? picture.url ?? '';
      if (url.length > 0) {
        media.imageUrls.push(url);
      }
    });
    const info: ApiUrls | undefined = raw.page_info?.media_info;
    media.videoUrl = info?.mp4_720p_mp4 ?? info?.stream_url_hd ?? info?.mp4_hd_mp4 ??
      info?.stream_url ?? info?.mp4_ld_mp4 ?? '';
    media.videoPosterUrl = raw.page_info?.page_pic?.url ?? '';
    media.pageTitle = raw.page_info?.page_title ?? raw.page_info?.content1 ?? '';
    if (WeiboParser.isLivePage(raw.page_info)) {
      media.kind = WeiboMediaKind.LIVE;
      media.liveState = WeiboParser.liveState(info);
      media.pageUrl = WeiboParser.livePageUrl(raw.page_info);
    } else if (media.videoUrl.length > 0) {
      media.kind = WeiboMediaKind.VIDEO;
      media.pageUrl = WeiboParser.httpUrl(raw.page_info?.page_url ?? '');
    } else if (media.imageUrls.length > 0) {
      media.kind = WeiboMediaKind.IMAGE;
    }
    return media;
  }

  private static httpUrl(value: string): string {
    return value.startsWith('https://') || value.startsWith('http://') ? value : '';
  }

  private static officialWeiboHttpsUrl(value: string): string {
    const pattern: RegExp = /^https:\/\/([a-z0-9-]+\.)*(weibo\.com|weibo\.cn)(:443)?([\/?#]|$)/i;
    return pattern.test(value) ? value : '';
  }

  private static livePageUrl(pageInfo: ApiPageInfo | undefined): string {
    if (pageInfo === undefined) {
      return '';
    }
    const info: ApiUrls | undefined = pageInfo.media_info;
    const h5Url: string = WeiboParser.officialWeiboHttpsUrl(info?.h5_url ?? '');
    if (h5Url.length > 0) {
      return h5Url;
    }
    const pageUrl: string = WeiboParser.officialWeiboHttpsUrl(pageInfo.page_url ?? '');
    const normalizedPageUrl: string = pageUrl.toLowerCase();
    if (normalizedPageUrl.includes('/l/wblive/') || normalizedPageUrl.includes('/live/')) {
      return pageUrl;
    }
    const liveId: string = info?.live_id ?? pageInfo.object_id ?? '';
    if (liveId.length > 0) {
      const encodedId: string = encodeURIComponent(liveId).replace('%3A', ':');
      return 'https://weibo.com/l/wblive/m/show/' + encodedId;
    }
    return pageUrl;
  }

  private static isLivePage(pageInfo: ApiPageInfo | undefined): boolean {
    if (pageInfo === undefined) {
      return false;
    }
    const type: string = (pageInfo.type ?? '').toLowerCase();
    const objectType: string = (pageInfo.object_type ?? '').toString().toLowerCase();
    const pageUrl: string = (pageInfo.page_url ?? '').toLowerCase();
    const info: ApiUrls | undefined = pageInfo.media_info;
    return type === 'live' || objectType === 'live' || objectType === 'wblive' || objectType === 'chatroom' ||
      pageUrl.includes('/l/wblive/') || pageUrl.includes('/live/') ||
      info?.is_living !== undefined || info?.live_status !== undefined;
  }

  private static liveState(info: ApiUrls | undefined): WeiboLiveState {
    if (info?.is_living === true) {
      return WeiboLiveState.ACTIVE;
    }
    if (info?.is_living === false) {
      return WeiboLiveState.ENDED;
    }
    const status: string = info?.live_status?.toString().toLowerCase() ?? '';
    if (status === '1' || status === 'live' || status === 'living' || status === 'active') {
      return WeiboLiveState.ACTIVE;
    }
    if (status === '0' || status === '3' || status === 'ended' || status === 'replay' || status === 'offline') {
      return WeiboLiveState.ENDED;
    }
    return WeiboLiveState.UNKNOWN;
  }

  private static toComment(raw: ApiComment): WeiboComment {
    const comment: WeiboComment = new WeiboComment();
    comment.id = raw.idstr ?? raw.id?.toString() ?? '';
    const emptyUser: ApiUser = {};
    comment.user = WeiboParser.toUser(raw.user ?? emptyUser);
    const commentContent: SocialTextContent = SocialTextParser.parse(raw.text_raw ?? '', raw.text ?? '');
    comment.text = commentContent.text;
    comment.textEntities = commentContent.entities;
    comment.createdAt = raw.created_at ?? '';
    comment.likesCount = raw.like_counts ?? raw.like_count ?? 0;
    comment.replyCount = raw.total_number ?? raw.comments?.length ?? 0;
    comment.replies = (raw.comments ?? []).map((item: ApiComment) => WeiboParser.toComment(item));
    comment.repliesLoaded = comment.replyCount > 0 && comment.replies.length >= comment.replyCount;
    return comment;
  }

  private static cleanText(value: string): string {
    return SocialTextParser.clean(value);
  }
}
