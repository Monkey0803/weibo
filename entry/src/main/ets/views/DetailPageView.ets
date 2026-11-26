import { CommentLoadMode, LoadState, PostRouteParam, UserRouteParam, WeiboComment,
  WeiboPost } from '../model/WeiboModels';
import { CommentSubmitOutcome, DetailViewModel } from '../viewmodel/DetailViewModel';
import { authViewModel } from '../viewmodel/AuthViewModel';
import { RouterConstants } from '../common/constants/RouterConstants';
import { CommonConstants } from '../common/constants/CommonConstants';
import { safeArea } from '../service/SafeAreaController';
import { scrollers } from '../service/ScrollerRegistry';
import { notificationService } from '../service/NotificationService';
import { MaterialController } from '../service/MaterialController';
import { ThemeColorController } from '../service/ThemeColorController';
import { appSettings } from '../model/AppSettings';
import { MaterialKind } from '../common/constants/SettingsConstants';
import { HdsBarWidthRangeOptions, HdsTabs, HdsTabsFloatingStyle } from '@kit.UIDesignKit';
import { ResponsiveContent } from './ResponsiveContent';
import { WeiboPostCard } from './WeiboPostCard';
import { MenuItemSpec, MenuSpec } from '../common/components/MenuSpec';
import { AppMenu } from '../common/components/AppMenu';
import { contentActionService } from '../service/ContentActionService';

const COMMENT_INPUT_ID: string = 'detail-comment-input';

@ComponentV2
export struct DetailPageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: PostRouteParam = new PostRouteParam(new WeiboPost());
  @Local commentText: string = '';
  @Local tabsWidthVp: number = 0;
  @Local composerHeightVp: number = 64;
  @Local focusCommentsPending: boolean = false;
  @Local viewportHeightVp: number = 0;
  @Local postHeightVp: number = 0;
  @Local commentsHeaderHeightVp: number = 0;
  @Local commentsStateHeightVp: number = 0;
  private viewModel: DetailViewModel = new DetailViewModel();

  aboutToAppear(): void {
    this.focusCommentsPending = this.routeParam.focusComments;
    this.viewModel.load(this.routeParam.post);
  }

  private focusCommentsAndComposer(): void {
    try {
      scrollers.detail.scrollToIndex(2, true, ScrollAlign.START);
    } catch (_err) {
      this.focusCommentsPending = true;
      return;
    }
    setTimeout((): void => this.requestCommentFocus(), 100);
  }

  private handleCommentListReady(width: number): void {
    if (width <= 0 || !this.focusCommentsPending) {
      return;
    }
    this.focusCommentsPending = false;
    setTimeout((): void => this.focusCommentsAndComposer(), 0);
  }

  private async sendComment(): Promise<void> {
    if (!this.canSendComment()) {
      return;
    }
    if (!authViewModel.loggedIn) {
      this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
      return;
    }
    const outcome: CommentSubmitOutcome = await this.viewModel.createComment(this.commentText);
    if (outcome === CommentSubmitOutcome.SENT) {
      this.commentText = '';
      notificationService.showSuccess(this.getUIContext(), $r('app.string.comment_sent'));
    } else if (outcome === CommentSubmitOutcome.SENT_REFRESH_FAILED) {
      this.commentText = '';
      notificationService.showWithAction(this.getUIContext(), $r('app.string.comment_sent_refresh_failed'),
        $r('app.string.action_retry'), () => this.viewModel.loadComments());
    } else if (outcome === CommentSubmitOutcome.RESULT_UNKNOWN) {
      notificationService.showError(this.getUIContext(), $r('app.string.comment_result_unknown'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.mutation_failed'));
    }
  }

  private canSendComment(): boolean {
    return this.commentText.trim().length > 0 && !this.viewModel.mutating;
  }

  private openCommentAuthor(comment: WeiboComment): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_PROFILE,
      new UserRouteParam(comment.user.id, comment.user.name)));
  }

  private async copyComment(comment: WeiboComment): Promise<void> {
    const success: boolean = await contentActionService.copy(comment.text);
    if (success) {
      notificationService.showSuccess(this.getUIContext(), $r('app.string.notice_copied'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_copy_failed'));
    }
  }

  private commentMenuSpec(comment: WeiboComment): MenuSpec {
    return MenuSpec.fromItems([
      new MenuItemSpec('author', $r('app.string.action_view_author'), () => this.openCommentAuthor(comment)),
      new MenuItemSpec('copy', $r('app.string.action_copy_text'), () => this.copyComment(comment))
    ]);
  }

  @Builder
  CommentMenu(comment: WeiboComment) {
    AppMenu(this.commentMenuSpec(comment));
  }

  private requestCommentFocus(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(COMMENT_INPUT_ID);
    } catch (_err) {
      // HdsTabs 仍在切换布局时可能暂时找不到输入框，用户下一次点击会再次请求焦点。
    }
  }

  private materialActive(): boolean {
    if (!appSettings.immersiveOn || appSettings.materialType === MaterialKind.NONE ||
      !MaterialController.appMaterialOn()) {
      return false;
    }
    if (appSettings.materialType === MaterialKind.IMMERSIVE) {
      return MaterialController.immersiveSupported();
    }
    return MaterialController.supportedTypes().length > 0;
  }

  private composerBarWidth(): number {
    return Math.max(this.tabsWidthVp - 2 * 16, 84);
  }

  private composerFloatingStyle(): HdsTabsFloatingStyle {
    const width: number = this.composerBarWidth();
    const barWidth: HdsBarWidthRangeOptions = {
      smallWidth: width,
      mediumWidth: width,
      largeWidth: width
    };
    const style: HdsTabsFloatingStyle = {
      barWidth: barWidth,
      barSideMargin: $r('app.float.space_l'),
      barBottomMargin: safeArea.bottomInsetVp,
      gradientMask: { maskColor: Color.Transparent },
      lightColor: ThemeColorController.brand(),
      systemMaterialEffect: MaterialController.params(appSettings.materialType,
        appSettings.materialLevel, appSettings.immersiveOn)
    };
    return style;
  }

  @Builder
  commentComposer() {
    Row({ space: $r('app.float.space_s') }) {
      Stack({ alignContent: Alignment.End }) {
        TextArea({ text: this.commentText, placeholder: $r('app.string.comment_hint') })
          .id(COMMENT_INPUT_ID)
          .focusOnTouch(true)
          .onClick(() => this.requestCommentFocus())
          .onChange((value: string) => this.commentText = value)
          .enterKeyType(EnterKeyType.NEW_LINE)
          .minLines(1)
          .textOverflow(TextOverflow.Clip)
          .maxLines(4, { overflowMode: MaxLinesMode.SCROLL })
          .barState(BarState.Auto)
          .fontSize($r('app.float.font_size_body'))
          .fontColor(this.materialActive() ? $r('sys.color.font_primary') : $r('app.color.hm_text_primary'))
          .placeholderColor(this.materialActive()
            ? $r('sys.color.font_secondary') : $r('app.color.hm_text_secondary'))
          .caretColor(ThemeColorController.brand())
          .padding({
            left: $r('app.float.space_m'),
            right: $r('app.float.button_height'),
            top: $r('app.float.space_s'),
            bottom: $r('app.float.space_s')
          })
          .constraintSize({
            minHeight: $r('app.float.input_height'),
            maxHeight: $r('app.float.detail_comment_input_max_height')
          })
          .width('100%')
          .backgroundColor(this.materialActive() ? Color.Transparent : $r('app.color.hm_card_background'))
          .borderRadius($r('app.float.radius_small'))
        if (this.commentText.length > 0) {
          Button() {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize($r('app.float.icon_size_small'))
              .fontColor([this.materialActive()
                ? $r('sys.color.font_secondary') : $r('app.color.hm_text_secondary')])
          }
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .width($r('app.float.button_height'))
          .height($r('app.float.button_height'))
          .accessibilityText($r('app.string.action_clear_comment'))
          .onClick(() => this.commentText = '')
        }
      }
      .layoutWeight(1)
      Button() {
        SymbolGlyph($r('sys.symbol.paperplane_fill'))
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([this.canSendComment()
            ? ThemeColorController.brand() : $r('app.color.hm_text_secondary')])
      }
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .width($r('app.float.button_height'))
        .height($r('app.float.button_height'))
        .enabled(this.canSendComment())
        .accessibilityText($r('app.string.action_send'))
        .onClick(() => this.sendComment())
    }
    .width('100%')
    .padding($r('app.float.space_s'))
    .alignItems(VerticalAlign.Center)
    .borderRadius($r('app.float.radius_small'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const height: number = Number(newArea.height);
      if (height > 0 && height !== this.composerHeightVp) {
        this.composerHeightVp = height;
      }
    })
  }

  @Builder
  composerBackdrop() {
    Row()
      .width('100%')
      .height(this.composerHeightVp)
  }

  @Builder
  commentRow(comment: WeiboComment) {
    Row({ space: $r('app.float.space_m') }) {
      Image(comment.user.avatarUrl)
        .width($r('app.float.detail_comment_avatar_size'))
        .height($r('app.float.detail_comment_avatar_size'))
        .borderRadius($r('app.float.detail_comment_avatar_size'))
        .objectFit(ImageFit.Cover)
      Column({ space: $r('app.float.space_xs') }) {
        Text(comment.user.name)
          .fontSize($r('app.float.font_size_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hm_text_secondary'))
        Text(comment.text)
          .fontSize($r('app.float.font_size_body'))
          .fontColor($r('app.color.hm_text_primary'))
          .lineHeight($r('app.float.space_xl'))
          .width('100%')
        Text(comment.createdAt)
          .fontSize($r('app.float.font_size_metric'))
          .fontColor($r('app.color.hm_text_secondary'))
        if (comment.replyCount > 0 || comment.replies.length > 0) {
          Button(comment.repliesLoaded ? (comment.repliesHasMore ? $r('app.string.action_load_more_replies') :
            $r('app.string.replies_loaded')) : $r('app.string.action_view_replies', comment.replyCount))
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .enabled(!comment.repliesLoading && (!comment.repliesLoaded || comment.repliesHasMore))
            .onClick(() => this.viewModel.loadReplies(comment))
        }
        ForEach(comment.replies, (reply: WeiboComment) => {
          Column({ space: $r('app.float.space_xs') }) {
            Text(reply.user.name).fontSize($r('app.float.font_size_metric'))
              .fontColor(ThemeColorController.brand())
            Text(reply.text).fontSize($r('app.float.font_size_caption'))
              .fontColor($r('app.color.hm_text_primary'))
          }.width('100%').alignItems(HorizontalAlign.Start).padding($r('app.float.space_s'))
            .backgroundColor($r('app.color.hm_search_background')).borderRadius($r('app.float.radius_small'))
        }, (reply: WeiboComment) => reply.id)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button() {
        SymbolGlyph($r('sys.symbol.ellipsis_circle'))
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('app.color.hm_text_secondary')])
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .width($r('app.float.button_height'))
      .height($r('app.float.button_height'))
      .accessibilityText($r('app.string.action_more'))
      .bindMenu(this.CommentMenu(comment), MaterialController.menuOptions(appSettings.immersiveOn))
    }
    .width('100%')
    .padding({ top: $r('app.float.space_m'), bottom: $r('app.float.space_m') })
    .alignItems(VerticalAlign.Top)
    .bindContextMenu(this.CommentMenu(comment), ResponseType.LongPress)
  }

  @Builder
  commentsHeader() {
    Column({ space: $r('app.float.space_xs') }) {
      Row() {
        Text($r('app.string.comments_title'))
          .fontSize($r('app.float.font_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.hm_text_primary'))
        Blank()
        Text(this.viewModel.post.commentsCount.toString())
          .fontSize($r('app.float.font_size_caption'))
          .fontColor($r('app.color.hm_text_secondary'))
      }
      .width('100%')
      if (this.viewModel.commentLoadMode === CommentLoadMode.BASIC &&
        this.viewModel.commentsState !== LoadState.ERROR) {
        Text($r('app.string.comments_basic_sort_notice'))
        .fontSize($r('app.float.font_size_caption'))
        .fontColor($r('app.color.hm_text_secondary'))
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: $r('app.float.space_s'), bottom: $r('app.float.space_s') })
  }

  @Builder
  commentsState() {
    if (this.viewModel.commentsState === LoadState.LOADING) {
      Column({ space: $r('app.float.space_s') }) {
        LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size'))
        Text($r('app.string.loading')).fontColor($r('app.color.hm_text_secondary'))
      }
      .width('100%')
      .padding($r('app.float.space_xl'))
    } else if (this.viewModel.commentsState === LoadState.EMPTY) {
      Text($r('app.string.empty_comments'))
        .fontColor($r('app.color.hm_text_secondary'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding($r('app.float.space_xl'))
    } else if (this.viewModel.commentsState === LoadState.ERROR) {
      Column({ space: $r('app.float.space_s') }) {
        Text($r('app.string.error_api_unavailable'))
          .fontColor($r('app.color.hm_error'))
          .textAlign(TextAlign.Center)
        Button($r('app.string.action_retry'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => this.viewModel.loadComments())
      }
      .width('100%')
      .padding($r('app.float.space_xl'))
    }
  }

  @Builder
  commentList() {
    List({ scroller: scrollers.detail }) {
      ListItem() { Row().height(CommonConstants.TITLE_BAR_HEIGHT_VP) }
        .margin({ bottom: $r('app.float.space_l') })
      ListItem() {
        WeiboPostCard({
          post: this.viewModel.post,
          navPathStack: this.navPathStack,
          expanded: true,
          showMetrics: true,
          onCommentRequested: (): void => this.focusCommentsAndComposer()
        })
      }
      .margin({ bottom: $r('app.float.space_xl') })
      .onAreaChange((_oldArea: Area, newArea: Area) => this.postHeightVp = Number(newArea.height))
      ListItem() { this.commentsHeader() }
        .onAreaChange((_oldArea: Area, newArea: Area) => this.commentsHeaderHeightVp = Number(newArea.height))
      ListItem() { this.commentsState() }
        .onAreaChange((_oldArea: Area, newArea: Area) => this.commentsStateHeightVp = Number(newArea.height))
      ForEach(this.viewModel.comments, (comment: WeiboComment) => {
        ListItem() {
          Column() {
            this.commentRow(comment)
            Divider()
              .color($r('app.color.hm_divider'))
              .margin({ left: $r('app.float.detail_comment_indent') })
          }
        }
      }, (comment: WeiboComment) => comment.id)
      if (this.viewModel.loadingMoreComments) {
        ListItem() {
          Row({ space: $r('app.float.space_s') }) {
            LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size'))
            Text($r('app.string.loading_more')).fontColor($r('app.color.hm_text_secondary'))
          }.width('100%').justifyContent(FlexAlign.Center).padding($r('app.float.space_m'))
        }
      } else if (this.viewModel.loadMoreCommentsFailed) {
        ListItem() {
          Column({ space: $r('app.float.space_s') }) {
            Text(this.viewModel.loadMoreCommentsError.length > 0
              ? this.viewModel.loadMoreCommentsError : $r('app.string.error_api_unavailable'))
              .fontColor($r('app.color.hm_error'))
              .textAlign(TextAlign.Center)
            Button($r('app.string.action_retry'))
              .buttonStyle(ButtonStyleMode.TEXTUAL)
              .onClick(() => this.viewModel.loadMoreComments())
          }.width('100%').padding($r('app.float.space_m'))
        }
      } else if (this.viewModel.commentsHasMore) {
        ListItem() {
          Button($r('app.string.action_load_more_comments'))
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .width('100%')
            .onClick(() => this.viewModel.loadMoreComments())
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
    .contentEndOffset(Math.max(this.composerHeightVp + safeArea.bottomInsetVp,
      this.viewModel.comments.length === 0
        ? CommonConstants.shortContentEndOffset(this.viewportHeightVp,
          CommonConstants.TITLE_BAR_HEIGHT_VP + this.postHeightVp +
          this.commentsHeaderHeightVp + this.commentsStateHeightVp) : 0))
    .scrollBar(BarState.Off)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.viewportHeightVp = Number(newArea.height);
      this.handleCommentListReady(Number(newArea.width));
    })
  }

  @Builder
  detailTabs() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsTabs() {
        TabContent() {
          this.commentList()
        }
        .tabBar(this.composerBackdrop())
      }
      .barPosition(BarPosition.End)
      .barOverlap(true)
      .barHeight(this.composerHeightVp)
      .scrollable(false)
      // HDS 只负责同位置的材质背板，输入控件作为可聚焦浮层放在其上方。
      .barBackgroundColor($r('app.color.hm_card_background'))
      .barFloatingStyle(this.composerFloatingStyle())
      .width('100%')
      .height('100%')
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const width: number = Number(newArea.width);
        if (width > 0 && width !== this.tabsWidthVp) {
          this.tabsWidthVp = width;
        }
      })

      Row() {
        this.commentComposer()
      }
      .width('100%')
      .padding({
        left: $r('app.float.space_l'),
        right: $r('app.float.space_l'),
        bottom: safeArea.bottomInsetVp
      })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    ResponsiveContent() {
      this.detailTabs()
    }
  }
}
