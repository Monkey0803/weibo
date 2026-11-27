import { LoadState, PageResult, Result, WeiboPost } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class RepostListViewModel {
  @Trace posts: WeiboPost[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = false;
  @Trace errorMessage: string = '';
  private postId: string = '';
  private page: number = 1;

  async load(postId: string): Promise<void> {
    this.postId = postId;
    this.state = LoadState.LOADING;
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.reposts(postId, 1);
    if (result.success && result.data) {
      this.posts = result.data.items;
      this.page = 1;
      this.hasMore = result.data.hasMore;
      this.state = this.posts.length > 0 ? LoadState.READY : LoadState.EMPTY;
    } else {
      this.errorMessage = result.message;
      this.state = LoadState.ERROR;
    }
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore) {
      return;
    }
    this.loadingMore = true;
    const next: number = this.page + 1;
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.reposts(this.postId, next);
    if (result.success && result.data) {
      this.posts = this.posts.concat(result.data.items);
      this.page = next;
      this.hasMore = result.data.hasMore;
    }
    this.loadingMore = false;
  }
}
