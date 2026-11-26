import { LoadState, PageResult, Result, WeiboPost } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class SearchViewModel {
  @Trace keyword: string = '';
  @Trace posts: WeiboPost[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = false;
  @Trace errorMessage: string = '';
  private page: number = 1;
  private requestSequence: number = 0;

  async search(keyword: string): Promise<void> {
    const normalized: string = keyword.trim();
    if (normalized.length === 0) {
      return;
    }
    const sequence: number = ++this.requestSequence;
    this.keyword = normalized;
    this.state = LoadState.LOADING;
    this.errorMessage = '';
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.search(normalized, 1);
    if (sequence !== this.requestSequence) {
      return;
    }
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
    if (this.loadingMore || !this.hasMore || this.keyword.length === 0) {
      return;
    }
    this.loadingMore = true;
    const nextPage: number = this.page + 1;
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.search(this.keyword, nextPage);
    if (result.success && result.data) {
      this.posts = this.posts.concat(result.data.items);
      this.page = nextPage;
      this.hasMore = result.data.hasMore;
    } else {
      this.errorMessage = result.message;
    }
    this.loadingMore = false;
  }
}

export const searchViewModel: SearchViewModel = new SearchViewModel();
