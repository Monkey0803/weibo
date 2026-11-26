import { LoadState, PostRouteParam, WeiboComment, WeiboPost } from '../model/WeiboModels';
import { DetailViewModel } from '../viewmodel/DetailViewModel';
import { authViewModel } from '../viewmodel/AuthViewModel';
import { RouterConstants } from '../common/constants/RouterConstants';
import { safeArea } from '../service/SafeAreaController';
import { notificationService } from '../service/NotificationService';
import { ResponsiveContent } from './ResponsiveContent';
import { WeiboPostCard } from './WeiboPostCard';

@ComponentV2
export struct DetailPageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: PostRouteParam = new PostRouteParam(new WeiboPost());
  @Local commentText: string = '';
  private viewModel: DetailViewModel = new DetailViewModel();

  aboutToAppear(): void {
    this.viewModel.load(this.routeParam.post);
  }

  private async toggleLike(): Promise<void> {
    if (!authViewModel.loggedIn) {
      this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
      return;
    }
    const success: boolean = await this.viewModel.toggleLike();
    if (!success) {
      notificationService.show(this.getUIContext(), $r('app.string.mutation_failed'));
    }
  }

  private async sendComment(): Promise<void> {
    if (!authViewModel.loggedIn) {
      this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
      return;
    }
    if (await this.viewModel.createComment(this.commentText)) {
      this.commentText = '';
      notificationService.show(this.getUIContext(), $r('app.string.comment_sent'));
    } else {
      notificationService.show(this.getUIContext(), $r('app.string.mutation_failed'));
    }
  }

  @Builder
  actionRow() {
    Row({ space: $r('app.float.space_m') }) {
      Button() {
        Row({ space: $r('app.float.space_s') }) {
          SymbolGlyph(this.viewModel.post.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize($r('app.float.icon_size_small'))
          Text(this.viewModel.post.liked ? $r('app.string.action_unlike') : $r('app.string.action_like'))
        }
      }
      .buttonStyle(this.viewModel.post.liked ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.TEXTUAL)
      .enabled(!this.viewModel.mutating)
      .onClick(() => this.toggleLike())
      Text($r('app.string.post_likes', this.viewModel.post.likesCount))
        .fontSize($r('app.float.font_size_caption'))
        .fontColor($r('app.color.hm_text_secondary'))
    }.width('100%')
  }

  @Builder
  commentComposer() {
    Row({ space: $r('app.float.space_s') }) {
      TextInput({ text: this.commentText, placeholder: $r('app.string.comment_hint') })
        .onChange((value: string) => this.commentText = value)
        .layoutWeight(1)
        .height($r('app.float.input_height'))
      Button($r('app.string.action_send'))
        .enabled(this.commentText.trim().length > 0 && !this.viewModel.mutating)
        .onClick(() => this.sendComment())
    }.width('100%')
  }

  @Builder
  commentRow(comment: WeiboComment) {
    Row({ space: $r('app.float.space_m') }) {
      Image(comment.user.avatarUrl)
        .width($r('app.float.avatar_size'))
        .height($r('app.float.avatar_size'))
        .borderRadius($r('app.float.avatar_size'))
        .objectFit(ImageFit.Cover)
      Column({ space: $r('app.float.space_xs') }) {
        Text(comment.user.name).fontWeight(FontWeight.Medium).fontColor($r('app.color.hm_text_primary'))
        Text(comment.text).fontColor($r('app.color.hm_text_primary')).width('100%')
        Text(comment.createdAt).fontSize($r('app.float.font_size_metric'))
          .fontColor($r('app.color.hm_text_secondary'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding($r('app.float.space_m'))
    .backgroundColor($r('app.color.hm_card_background'))
    .borderRadius($r('app.float.radius_small'))
  }

  build() {
    ResponsiveContent() {
      List() {
        ListItem() { Row().height(safeArea.contentTopInsetVp) }
        ListItem() { WeiboPostCard({ post: this.viewModel.post, navPathStack: this.navPathStack }) }
        ListItem() { this.actionRow() }
        ListItem() {
          Text($r('app.string.comments_title'))
            .fontSize($r('app.float.font_size_title'))
            .fontWeight(FontWeight.Bold)
            .width('100%')
        }
        ListItem() { this.commentComposer() }
        if (this.viewModel.commentsState === LoadState.LOADING) {
          ListItem() { LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size')) }
        } else if (this.viewModel.commentsState === LoadState.EMPTY) {
          ListItem() { Text($r('app.string.empty_comments')).fontColor($r('app.color.hm_text_secondary')) }
        } else if (this.viewModel.commentsState === LoadState.ERROR) {
          ListItem() {
            Text($r('app.string.error_api_unavailable')).fontColor($r('app.color.hm_error'))
          }
        }
        ForEach(this.viewModel.comments, (comment: WeiboComment) => {
          ListItem() { this.commentRow(comment) }
        }, (comment: WeiboComment) => comment.id)
      }
      .width('100%').height('100%')
      .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
      .contentEndOffset(safeArea.contentBottomInsetVp)
      .scrollBar(BarState.Off)
    }
  }
}
