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

  async load(initial: WeiboPost): Promise<void> {
    this.post = initial;
    this.state = LoadState.LOADING;
    const detail: Result<WeiboPost> = await weiboRepository.postDetail(initial.id);
    if (detail.success && detail.data) {
      this.post = detail.data;
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
