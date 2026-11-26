import { PostRouteParam, UserRouteParam, VideoRouteParam, WeiboPost } from '../model/WeiboModels';
import { RouterConstants } from '../common/constants/RouterConstants';
import { AppIcon } from './AppIcon';

@ComponentV2
export struct WeiboPostCard {
  @Param post: WeiboPost = new WeiboPost();
  @Param navPathStack: NavPathStack = new NavPathStack();

  private openPost(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_DETAIL, new PostRouteParam(this.post)));
  }

  private openUser(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_PROFILE,
      new UserRouteParam(this.post.user.id, this.post.user.name)));
  }

  private openVideo(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_VIDEO,
      new VideoRouteParam(this.post.media.videoUrl, this.post.media.videoPosterUrl)));
  }

  @Builder
  userHeader() {
    Row({ space: $r('app.float.space_m') }) {
      Image(this.post.user.avatarUrl)
        .width($r('app.float.avatar_size'))
        .height($r('app.float.avatar_size'))
        .borderRadius($r('app.float.avatar_size'))
        .objectFit(ImageFit.Cover)
      Column({ space: $r('app.float.space_xs') }) {
        Text(this.post.user.name)
          .fontSize($r('app.float.font_size_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hm_text_primary'))
          .maxLines(1)
        Text(this.post.createdAt)
          .fontSize($r('app.float.font_size_caption'))
          .fontColor($r('app.color.hm_text_secondary'))
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .onClick(() => this.openUser())
  }

  @Builder
  mediaContent() {
    if (this.post.media.videoUrl.length > 0) {
      Stack({ alignContent: Alignment.Center }) {
        Image(this.post.media.videoPosterUrl)
          .width('100%')
          .height($r('app.float.media_height'))
          .objectFit(ImageFit.Cover)
          .borderRadius($r('app.float.radius_small'))
        Button() {
          AppIcon({
            source: $r('app.media.icon_play'),
            iconSize: $r('app.float.hero_icon_size'),
            tint: $r('sys.color.white')
          })
        }
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .backgroundColor($r('app.color.hm_scrim'))
        .accessibilityText($r('app.string.action_play_video'))
      }
      .width('100%')
      .onClick(() => this.openVideo())
    } else if (this.post.media.imageUrls.length > 0) {
      Image(this.post.media.imageUrls[0])
        .width('100%')
        .height($r('app.float.media_height'))
        .objectFit(ImageFit.Cover)
        .borderRadius($r('app.float.radius_small'))
    }
  }

  @Builder
  metrics() {
    Row() {
      Text($r('app.string.post_reposts', this.post.repostsCount))
        .fontSize($r('app.float.font_size_metric')).fontColor($r('app.color.hm_text_secondary'))
      Text($r('app.string.post_comments', this.post.commentsCount))
        .fontSize($r('app.float.font_size_metric')).fontColor($r('app.color.hm_text_secondary'))
      Text($r('app.string.post_likes', this.post.likesCount))
        .fontSize($r('app.float.font_size_metric')).fontColor($r('app.color.hm_text_secondary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  build() {
    Column({ space: $r('app.float.space_m') }) {
      this.userHeader()
      Text(this.post.text)
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_primary'))
        .lineHeight($r('app.float.space_xl'))
        .width('100%')
      this.mediaContent()
      if (this.post.repost) {
        Text(this.post.repost.user.name + '：' + this.post.repost.text)
          .fontSize($r('app.float.font_size_caption'))
          .fontColor($r('app.color.hm_text_secondary'))
          .width('100%')
          .padding($r('app.float.space_m'))
          .backgroundColor($r('app.color.hm_brand_soft'))
          .borderRadius($r('app.float.radius_small'))
      }
      this.metrics()
    }
    .width('100%')
    .padding($r('app.float.space_l'))
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.hm_card_background'))
    .borderRadius($r('app.float.radius_card'))
    .onClick(() => this.openPost())
  }
}
