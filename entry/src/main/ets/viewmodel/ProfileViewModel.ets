import { LoadState, PageResult, Result, WeiboPost, WeiboUser } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class ProfileViewModel {
  @Trace user: WeiboUser = new WeiboUser();
  @Trace posts: WeiboPost[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace errorMessage: string = '';
  private userId: string = '';

  async load(userId: string): Promise<void> {
    if (userId.length === 0) {
      this.state = LoadState.EMPTY;
      return;
    }
    this.userId = userId;
    this.state = LoadState.LOADING;
    this.errorMessage = '';
    const profile: Result<WeiboUser> = await weiboRepository.profile(userId);
    const posts: Result<PageResult<WeiboPost>> = await weiboRepository.userPosts(userId, 1);
    if (profile.success && profile.data) {
      this.user = profile.data;
    }
    if (posts.success && posts.data) {
      this.posts = posts.data.items;
    }
    if (profile.success || posts.success) {
      this.state = LoadState.READY;
    } else {
      this.errorMessage = profile.message.length > 0 ? profile.message : posts.message;
      this.state = LoadState.ERROR;
    }
  }
}
