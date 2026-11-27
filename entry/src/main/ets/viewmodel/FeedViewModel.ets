import { FeedKind, LoadState, PageResult, Result, WeiboPost } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class FeedViewModel {
  @Trace kind: FeedKind = FeedKind.HOT;
  @Trace posts: WeiboPost[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace loadingMore: boolean = false;
  @Trace refreshing: boolean = false;
  @Trace hasMore: boolean = false;
  @Trace errorMessage: string = '';
  @Trace authRequired: boolean = false;
  @Trace loadMoreErrorMessage: string = '';
  @Trace loadMoreAuthRequired: boolean = false;
  @Trace loadMoreFailed: boolean = false;
  private page: number = 1;
  private cursor: string = '';
  private requestSequence: number = 0;

  async select(kind: FeedKind): Promise<void> {
    if (this.kind === kind && this.posts.length > 0) {
      return;
    }
    this.kind = kind;
    this.posts = [];
    this.hasMore = false;
    this.cursor = '';
    this.page = 1;
    await this.refresh();
  }

  async refresh(): Promise<void> {
    const sequence: number = ++this.requestSequence;
    this.refreshing = this.posts.length > 0;
    this.state = LoadState.LOADING;
    this.errorMessage = '';
    this.authRequired = false;
    this.loadMoreErrorMessage = '';
    this.loadMoreAuthRequired = false;
    this.loadMoreFailed = false;
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.feed(this.kind, 1, '');
    if (sequence !== this.requestSequence) {
      return;
    }
    if (result.success && result.data) {
      this.posts = result.data.items;
      this.page = 1;
      this.cursor = result.data.nextCursor;
      this.hasMore = result.data.hasMore;
      this.state = this.posts.length > 0 ? LoadState.READY : LoadState.EMPTY;
    } else {
      this.errorMessage = result.message;
      this.authRequired = result.authRequired;
      this.state = LoadState.ERROR;
    }
    this.refreshing = false;
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore || this.state !== LoadState.READY) {
      return;
    }
    this.loadingMore = true;
    this.loadMoreErrorMessage = '';
    this.loadMoreAuthRequired = false;
    this.loadMoreFailed = false;
    const nextPage: number = this.page + 1;
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.feed(this.kind, nextPage, this.cursor);
    if (result.success && result.data) {
      this.posts = this.merge(this.posts, result.data.items);
      this.page = nextPage;
      this.cursor = result.data.nextCursor;
      this.hasMore = result.data.hasMore;
    } else {
      this.loadMoreFailed = true;
      this.loadMoreErrorMessage = result.message;
      this.loadMoreAuthRequired = result.authRequired;
    }
    this.loadingMore = false;
  }

  clearProtected(): void {
    if (this.kind !== FeedKind.FOLLOWING) {
      return;
    }
    this.posts = [];
    this.state = LoadState.IDLE;
    this.hasMore = false;
    this.page = 1;
    this.cursor = '';
    this.errorMessage = '';
    this.loadMoreErrorMessage = '';
    this.loadMoreFailed = false;
  }

  private merge(current: WeiboPost[], incoming: WeiboPost[]): WeiboPost[] {
    const result: WeiboPost[] = current.slice();
    const ids: Set<string> = new Set<string>();
    current.forEach((post: WeiboPost) => ids.add(post.id));
    incoming.forEach((post: WeiboPost) => {
      if (!ids.has(post.id)) {
        ids.add(post.id);
        result.push(post);
      }
    });
    return result;
  }
}

export const feedViewModel: FeedViewModel = new FeedViewModel();
