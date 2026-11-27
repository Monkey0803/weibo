import { LoadState, PageResult, Result, SocialListKind, WeiboUser } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class SocialListViewModel {
  @Trace users: WeiboUser[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = false;
  @Trace errorMessage: string = '';
  private userId: string = '';
  private kind: SocialListKind = SocialListKind.FOLLOWING;
  private page: number = 1;

  async load(userId: string, kind: SocialListKind): Promise<void> {
    this.userId = userId;
    this.kind = kind;
    this.state = LoadState.LOADING;
    const result: Result<PageResult<WeiboUser>> = await weiboRepository.socialUsers(
      userId, kind === SocialListKind.FOLLOWERS, 1);
    if (result.success && result.data) {
      this.users = result.data.items;
      this.page = 1;
      this.hasMore = result.data.hasMore;
      this.state = this.users.length > 0 ? LoadState.READY : LoadState.EMPTY;
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
    const result: Result<PageResult<WeiboUser>> = await weiboRepository.socialUsers(
      this.userId, this.kind === SocialListKind.FOLLOWERS, next);
    if (result.success && result.data) {
      this.users = this.users.concat(result.data.items);
      this.page = next;
      this.hasMore = result.data.hasMore;
    }
    this.loadingMore = false;
  }
}
