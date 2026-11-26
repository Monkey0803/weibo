import { LoadState, WeiboPost } from '../model/WeiboModels';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';
import { WeiboPostCard } from './WeiboPostCard';

@ComponentV2
export struct ProfileContent {
  @Param viewModel: ProfileViewModel = new ProfileViewModel();
  @Param navPathStack: NavPathStack = new NavPathStack();

  @Builder
  profileHeader() {
    Column({ space: $r('app.float.space_m') }) {
      Image(this.viewModel.user.avatarUrl)
        .width($r('app.float.avatar_size_large'))
        .height($r('app.float.avatar_size_large'))
        .borderRadius($r('app.float.avatar_size_large'))
        .objectFit(ImageFit.Cover)
      Text(this.viewModel.user.name)
        .fontSize($r('app.float.font_size_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.hm_text_primary'))
      Text(this.viewModel.user.description)
        .fontSize($r('app.float.font_size_caption'))
        .fontColor($r('app.color.hm_text_secondary'))
        .textAlign(TextAlign.Center)
      Row() {
        Text($r('app.string.profile_following', this.viewModel.user.followingCount))
          .fontSize($r('app.float.font_size_caption')).fontColor($r('app.color.hm_text_secondary'))
        Text($r('app.string.profile_followers', this.viewModel.user.followersCount))
          .fontSize($r('app.float.font_size_caption')).fontColor($r('app.color.hm_text_secondary'))
        Text($r('app.string.profile_posts', this.viewModel.user.statusesCount))
          .fontSize($r('app.float.font_size_caption')).fontColor($r('app.color.hm_text_secondary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .padding($r('app.float.space_l'))
    .backgroundColor($r('app.color.hm_card_background'))
    .borderRadius($r('app.float.radius_card'))
  }

  build() {
    Column({ space: $r('app.float.space_m') }) {
      if (this.viewModel.state === LoadState.LOADING) {
        LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size'))
      } else if (this.viewModel.state === LoadState.ERROR) {
        if (this.viewModel.errorMessage.length > 0) {
          Text(this.viewModel.errorMessage).fontColor($r('app.color.hm_error'))
        } else {
          Text($r('app.string.error_api_unavailable')).fontColor($r('app.color.hm_error'))
        }
      } else if (this.viewModel.state === LoadState.READY) {
        this.profileHeader()
        ForEach(this.viewModel.posts, (post: WeiboPost) => {
          WeiboPostCard({ post: post, navPathStack: this.navPathStack })
        }, (post: WeiboPost) => post.id)
      }
    }.width('100%')
  }
}
