import {
  ApiFailureKind,
  CommentLoadMode,
  CommentPageResult,
  LoadState,
  PageResult,
  Result,
  WeiboComment,
  WeiboLiveState,
  WeiboMediaKind,
  WeiboPost
} from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

export enum CommentSubmitOutcome {
  SENT = 0,
  SENT_REFRESH_FAILED = 1,
  RESULT_UNKNOWN = 2,
  FAILED = 3
}

/** 微博分页接口会把“游标已耗尽”包装成 API_REJECTED；这是正常结束，不应展示错误。 */
export function isCommentPageExhausted(result: Result<CommentPageResult>): boolean {
  if (result.failureKind !== ApiFailureKind.API_REJECTED || result.authRequired || result.statusCode >= 400) {
    return false;
  }
  const message: string = result.message.trim().toLowerCase().replace(/[。.!！]+$/, '');
  return ['暂无数据', '没有数据', '暂无更多数据', '没有更多数据', '暂无更多评论', '没有更多评论',
    '已全部加载', 'no data', 'no more data', 'no more comments'].includes(message);
}

export function commentsStateAfterExhaustion(commentCount: number): LoadState {
  return commentCount > 0 ? LoadState.READY : LoadState.EMPTY;
}

export function prepareDetailFallback(initial: WeiboPost): WeiboPost {
  if (initial.isLongText) {
    initial.fullTextUnavailable = true;
  }
  return initial;
}

/** 详情接口可能只返回部分字段；缺失值沿用列表页已经拿到的微博，避免展开页内容退化。 */
export function mergePostDetail(detail: WeiboPost, initial: WeiboPost): WeiboPost {
  if (detail.id.length === 0) {
    detail.id = initial.id;
  }
  if (detail.mid.length === 0) {
    detail.mid = initial.mid;
  }
  if (detail.user.id.length === 0) {
    detail.user.id = initial.user.id;
  }
  if (detail.user.name.length === 0) {
    detail.user.name = initial.user.name;
  }
  if (detail.user.avatarUrl.length === 0) {
    detail.user.avatarUrl = initial.user.avatarUrl;
  }
  if (detail.user.description.length === 0) {
    detail.user.description = initial.user.description;
    detail.user.descriptionEntities = initial.user.descriptionEntities;
  }
  if (detail.text.length === 0) {
    detail.text = initial.text;
  }
  if (detail.createdAt.length === 0) {
    detail.createdAt = initial.createdAt;
  }
  if (detail.source.length === 0) {
    detail.source = initial.source;
  }
  if (!detail.isLongText) {
    detail.isLongText = initial.isLongText;
  }
  if (detail.media.imageUrls.length === 0) {
    detail.media.imageUrls = initial.media.imageUrls;
  }
  if (detail.media.videoUrl.length === 0) {
    detail.media.videoUrl = initial.media.videoUrl;
  }
  if (detail.media.videoPosterUrl.length === 0) {
    detail.media.videoPosterUrl = initial.media.videoPosterUrl;
  }
  // 详情接口有时只保留直播流地址，却不再携带直播类型。列表页已经确认是直播时，
  // 将直播语义作为整体保留，避免详情页误走普通视频播放器。
  if (initial.media.kind === WeiboMediaKind.LIVE && detail.media.kind !== WeiboMediaKind.LIVE) {
    detail.media.kind = WeiboMediaKind.LIVE;
    detail.media.pageUrl = initial.media.pageUrl;
    detail.media.pageTitle = initial.media.pageTitle;
    detail.media.liveState = initial.media.liveState;
  } else {
    if (detail.media.kind === WeiboMediaKind.NONE) {
      detail.media.kind = initial.media.kind;
    }
    if (detail.media.pageUrl.length === 0) {
      detail.media.pageUrl = initial.media.pageUrl;
    }
    if (detail.media.pageTitle.length === 0) {
      detail.media.pageTitle = initial.media.pageTitle;
    }
    if (detail.media.liveState === WeiboLiveState.UNKNOWN) {
      detail.media.liveState = initial.media.liveState;
    }
  }
  if (detail.repost === undefined) {
    detail.repost = initial.repost;
  }
  return detail;
}

@ObservedV2
export class DetailViewModel {
  @Trace post: WeiboPost = new WeiboPost();
  @Trace comments: WeiboComment[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace commentsState: LoadState = LoadState.IDLE;
  @Trace mutating: boolean = false;
  @Trace errorMessage: string = '';
  @Trace commentsHasMore: boolean = false;
  @Trace commentLoadMode: CommentLoadMode = CommentLoadMode.HOT;
  @Trace loadingMoreComments: boolean = false;
  @Trace loadMoreCommentsError: string = '';
  @Trace loadMoreCommentsFailed: boolean = false;
  private cursor: string = '';

  async load(initial: WeiboPost): Promise<void> {
    this.post = initial;
    this.state = LoadState.LOADING;
    const detail: Result<WeiboPost> = await weiboRepository.postDetail(initial.id);
    if (detail.success && detail.data) {
      this.post = mergePostDetail(detail.data, initial);
      this.state = LoadState.READY;
    } else {
      this.post = prepareDetailFallback(initial);
      this.state = initial.id.length > 0 ? LoadState.READY : LoadState.ERROR;
      this.errorMessage = detail.message;
    }
    await this.loadComments();
  }

  async loadComments(): Promise<void> {
    this.commentsState = LoadState.LOADING;
    this.loadMoreCommentsError = '';
    this.loadMoreCommentsFailed = false;
    const result: Result<CommentPageResult> =
      await weiboRepository.comments(this.post.id, this.post.mid, '');
    if (result.success && result.data) {
      this.comments = result.data.items;
      this.cursor = result.data.nextCursor;
      this.commentsHasMore = result.data.hasMore;
      this.commentLoadMode = result.data.mode;
      this.commentsState = this.comments.length > 0 ? LoadState.READY : LoadState.EMPTY;
    } else if (isCommentPageExhausted(result)) {
      this.cursor = '';
      this.commentsHasMore = false;
      this.commentsState = commentsStateAfterExhaustion(this.comments.length);
    } else {
      this.errorMessage = result.message;
      this.commentsState = LoadState.ERROR;
    }
  }

  async loadMoreComments(): Promise<void> {
    if (this.loadingMoreComments || !this.commentsHasMore || this.cursor.length === 0 ||
      this.commentsState !== LoadState.READY) {
      return;
    }
    this.loadingMoreComments = true;
    this.loadMoreCommentsError = '';
    this.loadMoreCommentsFailed = false;
    const result: Result<CommentPageResult> =
      await weiboRepository.comments(this.post.id, this.post.mid, this.cursor);
    if (result.success && result.data) {
      this.comments = this.mergeComments(this.comments, result.data.items);
      this.cursor = result.data.nextCursor;
      this.commentsHasMore = result.data.hasMore;
      this.commentLoadMode = result.data.mode;
    } else if (isCommentPageExhausted(result)) {
      this.cursor = '';
      this.commentsHasMore = false;
    } else {
      this.loadMoreCommentsFailed = true;
      this.loadMoreCommentsError = result.message;
    }
    this.loadingMoreComments = false;
  }

  async createComment(text: string): Promise<CommentSubmitOutcome> {
    if (this.mutating || text.trim().length === 0) {
      return CommentSubmitOutcome.FAILED;
    }
    this.mutating = true;
    try {
      const result: Result<WeiboComment> = await weiboRepository.createCommentDetail(this.post.id, text.trim());
      if (result.success && result.data) {
        this.comments = [result.data].concat(this.comments);
        this.post.commentsCount += 1;
        this.commentsState = LoadState.READY;
        return CommentSubmitOutcome.SENT;
      }
      this.errorMessage = result.message;
      return result.failureKind === ApiFailureKind.NETWORK
        ? CommentSubmitOutcome.RESULT_UNKNOWN : CommentSubmitOutcome.FAILED;
    } finally {
      this.mutating = false;
    }
  }

  async loadReplies(comment: WeiboComment): Promise<void> {
    if (comment.repliesLoading || comment.repliesLoaded && !comment.repliesHasMore) {
      return;
    }
    comment.repliesLoading = true;
    const cursor: string = comment.repliesLoaded ? comment.repliesCursor : '';
    const contentId: string = this.post.mid.length > 0 ? this.post.mid : this.post.id;
    const result: Result<PageResult<WeiboComment>> =
      await weiboRepository.commentReplies(contentId, comment.id, cursor);
    if (result.success && result.data) {
      comment.replies = this.mergeComments(comment.replies, result.data.items);
      comment.repliesCursor = result.data.nextCursor;
      comment.repliesHasMore = result.data.hasMore;
      comment.repliesLoaded = true;
      this.comments = this.comments.slice();
    }
    comment.repliesLoading = false;
    this.comments = this.comments.slice();
  }

  private mergeComments(current: WeiboComment[], incoming: WeiboComment[]): WeiboComment[] {
    const merged: WeiboComment[] = current.slice();
    const ids: Set<string> = new Set<string>();
    current.forEach((comment: WeiboComment) => ids.add(comment.id));
    incoming.forEach((comment: WeiboComment) => {
      if (!ids.has(comment.id)) {
        ids.add(comment.id);
        merged.push(comment);
      }
    });
    return merged;
  }
}
