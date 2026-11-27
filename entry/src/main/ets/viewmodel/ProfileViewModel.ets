import { LoadState, PageResult, Result, WeiboPost, WeiboUser } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class ProfileViewModel {
  @Trace user: WeiboUser = new WeiboUser();
  @Trace posts: WeiboPost[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace profileState: LoadState = LoadState.IDLE;
  @Trace postsState: LoadState = LoadState.IDLE;
  @Trace errorMessage: string = '';
  @Trace postsErrorMessage: string = '';
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = false;
  @Trace loadMoreErrorMessage: string = '';
  @Trace loadMoreFailed: boolean = false;
  @Trace followPending: boolean = false;
  private userId: string = '';
  private page: number = 1;

  async load(userId: string): Promise<void> {
    if (userId.length === 0) {
      this.state = LoadState.EMPTY;
      this.profileState = LoadState.EMPTY;
      this.postsState = LoadState.EMPTY;
      return;
    }
    this.userId = userId;
    this.state = LoadState.LOADING;
    this.profileState = LoadState.LOADING;
    this.postsState = LoadState.LOADING;
    this.errorMessage = '';
    this.postsErrorMessage = '';
    this.loadMoreErrorMessage = '';
    this.loadMoreFailed = false;
    const profile: Result<WeiboUser> = await weiboRepository.profile(userId);
    const posts: Result<PageResult<WeiboPost>> = await weiboRepository.userPosts(userId, 1);
    if (profile.success && profile.data) {
      this.user = profile.data;
      this.profileState = LoadState.READY;
    } else {
      this.errorMessage = profile.message;
      this.profileState = LoadState.ERROR;
    }
    if (posts.success && posts.data) {
      this.posts = posts.data.items;
      this.page = 1;
      this.hasMore = posts.data.hasMore;
      this.postsState = this.posts.length > 0 ? LoadState.READY : LoadState.EMPTY;
    } else {
      this.postsErrorMessage = posts.message;
      this.postsState = LoadState.ERROR;
    }
    if (profile.success || posts.success) {
      this.state = LoadState.READY;
    } else {
      this.errorMessage = profile.message.length > 0 ? profile.message : posts.message;
      this.state = LoadState.ERROR;
    }
  }

  async retry(): Promise<void> {
    await this.load(this.userId);
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore || this.userId.length === 0) {
      return;
    }
    this.loadingMore = true;
    this.loadMoreErrorMessage = '';
    this.loadMoreFailed = false;
    const nextPage: number = this.page + 1;
    const result: Result<PageResult<WeiboPost>> = await weiboRepository.userPosts(this.userId, nextPage);
    if (result.success && result.data) {
      this.posts = this.merge(this.posts, result.data.items);
      this.page = nextPage;
      this.hasMore = result.data.hasMore;
      this.postsState = this.posts.length > 0 ? LoadState.READY : LoadState.EMPTY;
    } else {
      this.loadMoreFailed = true;
      this.loadMoreErrorMessage = result.message;
    }
    this.loadingMore = false;
  }

  async toggleFollow(): Promise<Result<boolean>> {
    if (this.followPending || this.user.id.length === 0) {
      return Result.fail<boolean>('');
    }
    this.followPending = true;
    try {
      const wasFollowing: boolean = this.user.following;
      const result: Result<boolean> = await weiboRepository.follow(this.user.id, wasFollowing);
      if (result.success) {
        this.user.following = !wasFollowing;
        this.user.followersCount = Math.max(0, this.user.followersCount + (wasFollowing ? -1 : 1));
      }
      return result;
    } finally {
      this.followPending = false;
    }
  }

  clear(): void {
    this.userId = '';
    this.user = new WeiboUser();
    this.posts = [];
    this.state = LoadState.IDLE;
    this.profileState = LoadState.IDLE;
    this.postsState = LoadState.IDLE;
    this.hasMore = false;
    this.page = 1;
    this.errorMessage = '';
    this.postsErrorMessage = '';
    this.loadMoreErrorMessage = '';
    this.loadMoreFailed = false;
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

/** 主“我的”页与外层标题栏共享同一份资料状态。 */
export const profileTabViewModel: ProfileViewModel = new ProfileViewModel();
