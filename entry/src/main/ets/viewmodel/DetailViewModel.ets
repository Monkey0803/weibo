import {
  LoadState,
  PageResult,
  Result,
  WeiboComment,
  WeiboPost
} from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class DetailViewModel {
  @Trace post: WeiboPost = new WeiboPost();
  @Trace comments: WeiboComment[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace commentsState: LoadState = LoadState.IDLE;
  @Trace mutating: boolean = false;
  @Trace errorMessage: string = '';
  private cursor: string = '';

  /** 详情接口可能只返回部分字段；缺失值沿用列表页已经拿到的微博，避免展开页内容退化。 */
  private mergePost(detail: WeiboPost, initial: WeiboPost): WeiboPost {
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
    if (detail.media.imageUrls.length === 0) {
      detail.media.imageUrls = initial.media.imageUrls;
    }
    if (detail.media.videoUrl.length === 0) {
      detail.media.videoUrl = initial.media.videoUrl;
    }
    if (detail.media.videoPosterUrl.length === 0) {
      detail.media.videoPosterUrl = initial.media.videoPosterUrl;
    }
    if (detail.repost === undefined) {
      detail.repost = initial.repost;
    }
    return detail;
  }

  async load(initial: WeiboPost): Promise<void> {
    this.post = initial;
    this.state = LoadState.LOADING;
    const detail: Result<WeiboPost> = await weiboRepository.postDetail(initial.id);
    if (detail.success && detail.data) {
      this.post = this.mergePost(detail.data, initial);
      this.state = LoadState.READY;
    } else {
      this.state = initial.id.length > 0 ? LoadState.READY : LoadState.ERROR;
      this.errorMessage = detail.message;
    }
    await this.loadComments();
  }

  async loadComments(): Promise<void> {
    this.commentsState = LoadState.LOADING;
    const result: Result<PageResult<WeiboComment>> =
      await weiboRepository.comments(this.post.id, this.post.mid, '');
    if (result.success && result.data) {
      this.comments = result.data.items;
      this.cursor = result.data.nextCursor;
      this.commentsState = this.comments.length > 0 ? LoadState.READY : LoadState.EMPTY;
    } else {
      this.errorMessage = result.message;
      this.commentsState = LoadState.ERROR;
    }
  }

  async toggleLike(): Promise<boolean> {
    if (this.mutating) {
      return false;
    }
    this.mutating = true;
    const result: Result<boolean> = await weiboRepository.like(this.post.id, this.post.liked);
    if (result.success) {
      this.post.liked = !this.post.liked;
      this.post.likesCount += this.post.liked ? 1 : -1;
      this.post = this.post;
    } else {
      this.errorMessage = result.message;
    }
    this.mutating = false;
    return result.success;
  }

  async createComment(text: string): Promise<boolean> {
    if (this.mutating || text.trim().length === 0) {
      return false;
    }
    this.mutating = true;
    const result: Result<boolean> = await weiboRepository.createComment(this.post.id, text.trim());
    this.mutating = false;
    if (result.success) {
      await this.loadComments();
      return true;
    }
    this.errorMessage = result.message;
    return false;
  }
}
