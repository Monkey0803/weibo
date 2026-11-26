import { PageResult, SessionInfo, WeiboComment, WeiboMedia, WeiboPost, WeiboUser } from '../model/WeiboModels';

interface ApiUrls {
  mp4_720p_mp4?: string;
  mp4_hd_mp4?: string;
  mp4_ld_mp4?: string;
  stream_url_hd?: string;
  stream_url?: string;
}

interface ApiPageInfo {
  media_info?: ApiUrls;
  page_pic?: ApiPicture;
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
}

interface ApiEnvelope {
  ok?: number;
  msg?: string;
  message?: string;
  login?: boolean;
  uid?: string | number;
  data?: ApiData;
  statuses?: ApiStatus[];
}

interface ApiCommentData {
  data?: ApiComment[];
  comments?: ApiComment[];
  max_id?: number;
  max_id_str?: string;
}

interface ApiCommentEnvelope {
  data?: ApiCommentData;
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
    const rawItems: ApiStatus[] = [];
    if (envelope.data?.statuses) {
      rawItems.push(...envelope.data.statuses);
    } else if (envelope.statuses) {
      rawItems.push(...envelope.statuses);
    } else if (envelope.data?.data) {
      rawItems.push(...envelope.data.data);
    }
    WeiboParser.collectCardPosts(envelope.data?.cards ?? [], rawItems);
    const posts: WeiboPost[] = WeiboParser.deduplicate(
      rawItems.map((item: ApiStatus) => WeiboParser.toPost(item)));
    const cursor: string = envelope.data?.max_id_str ?? (envelope.data?.max_id?.toString() ?? '');
    const total: number = envelope.data?.pageInfo?.total ?? 0;
    const hasMore: boolean = cursor.length > 0 && cursor !== '0' || posts.length > 0 && (total === 0 || currentPage * 10 < total);
    return new PageResult<WeiboPost>(posts, cursor, hasMore);
  }

  static parsePost(content: string): WeiboPost {
    const status: ApiStatus = JSON.parse(content) as ApiStatus;
    return WeiboParser.toPost(status);
  }

  static parseComments(content: string): PageResult<WeiboComment> {
    const envelope: ApiCommentEnvelope = JSON.parse(content) as ApiCommentEnvelope;
    const comments: ApiComment[] = envelope.data?.comments ?? envelope.data?.data ?? [];
    const items: WeiboComment[] = comments.map((item: ApiComment) => WeiboParser.toComment(item));
    const cursor: string = envelope.data?.max_id_str ?? (envelope.data?.max_id?.toString() ?? '');
    return new PageResult<WeiboComment>(items, cursor, cursor.length > 0 && cursor !== '0');
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
    post.text = WeiboParser.cleanText(raw.text_raw ?? raw.text ?? '');
    post.createdAt = raw.created_at ?? '';
    post.source = WeiboParser.cleanText(raw.source ?? '');
    post.repostsCount = raw.reposts_count ?? 0;
    post.commentsCount = raw.comments_count ?? 0;
    post.likesCount = raw.attitudes_count ?? 0;
    post.liked = raw.liked ?? false;
    post.media = WeiboParser.toMedia(raw);
    if (raw.retweeted_status) {
      post.repost = WeiboParser.toPost(raw.retweeted_status);
    }
    return post;
  }

  private static toUser(raw: ApiUser): WeiboUser {
    const user: WeiboUser = new WeiboUser();
    user.id = raw.idstr ?? raw.id?.toString() ?? '';
    user.name = raw.screen_name ?? '';
    user.avatarUrl = raw.avatar_hd ?? raw.profile_image_url ?? '';
    user.description = raw.description ?? '';
    user.followersCount = raw.followers_count ?? 0;
    user.followingCount = raw.follow_count ?? raw.friends_count ?? 0;
    user.statusesCount = raw.statuses_count ?? 0;
    user.verified = raw.verified ?? false;
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
    return media;
  }

  private static toComment(raw: ApiComment): WeiboComment {
    const comment: WeiboComment = new WeiboComment();
    comment.id = raw.idstr ?? raw.id?.toString() ?? '';
    const emptyUser: ApiUser = {};
    comment.user = WeiboParser.toUser(raw.user ?? emptyUser);
    comment.text = WeiboParser.cleanText(raw.text_raw ?? raw.text ?? '');
    comment.createdAt = raw.created_at ?? '';
    comment.likesCount = raw.like_counts ?? 0;
    return comment;
  }

  private static cleanText(value: string): string {
    return value
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .trim();
  }
}
