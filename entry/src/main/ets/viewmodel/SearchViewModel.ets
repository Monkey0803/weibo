import { LoadState, PageResult, Result, SearchKind, WeiboPost } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class SearchViewModel {
  @Trace query: string = '';
  @Trace focused: boolean = false;
  @Trace keyword: string = '';
  @Trace posts: WeiboPost[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = false;
  @Trace errorMessage: string = '';
  @Trace loadMoreErrorMessage: string = '';
  @Trace loadMoreFailed: boolean = false;
  @Trace showingPreviousResults: boolean = false;
  @Trace kind: SearchKind = SearchKind.COMPREHENSIVE;
  private page: number = 1;
  private requestSequence: number = 0;

  async search(keyword: string): Promise<void> {
    const normalized: string = keyword.trim();
    if (normalized.length === 0) {
      return;
    }
    const sequence: number = ++this.requestSequence;
    this.showingPreviousResults = this.posts.length > 0 && normalized !== this.keyword;
    this.keyword = normalized;
    this.state = LoadState.LOADING;
    this.errorMessage = '';
    this.loadMoreErrorMessage = '';
    this.loadMoreFailed = false;
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.search(normalized, 1, this.kind);
    if (sequence !== this.requestSequence) {
      return;
    }
    if (result.success && result.data) {
      this.posts = result.data.items;
      this.page = 1;
      this.hasMore = result.data.hasMore;
      this.state = this.posts.length > 0 ? LoadState.READY : LoadState.EMPTY;
      this.showingPreviousResults = false;
    } else {
      this.errorMessage = result.message;
      this.state = LoadState.ERROR;
    }
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore || this.keyword.length === 0) {
      return;
    }
    this.loadingMore = true;
    this.loadMoreErrorMessage = '';
    this.loadMoreFailed = false;
    const nextPage: number = this.page + 1;
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.search(this.keyword, nextPage, this.kind);
    if (result.success && result.data) {
      this.posts = this.merge(this.posts, result.data.items);
      this.page = nextPage;
      this.hasMore = result.data.hasMore;
    } else {
      this.loadMoreFailed = true;
      this.loadMoreErrorMessage = result.message;
    }
    this.loadingMore = false;
  }

  async selectKind(kind: SearchKind): Promise<void> {
    if (this.kind === kind) {
      return;
    }
    this.kind = kind;
    if (this.keyword.length > 0) {
      await this.search(this.keyword);
    }
  }

  private merge(current: WeiboPost[], incoming: WeiboPost[]): WeiboPost[] {
    const merged: WeiboPost[] = current.slice();
    const ids: Set<string> = new Set<string>();
    current.forEach((post: WeiboPost) => ids.add(post.id));
    incoming.forEach((post: WeiboPost) => {
      if (!ids.has(post.id)) {
        ids.add(post.id);
        merged.push(post);
      }
    });
    return merged;
  }
}

export const searchViewModel: SearchViewModel = new SearchViewModel();
