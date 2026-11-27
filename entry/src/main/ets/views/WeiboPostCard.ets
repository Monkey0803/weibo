import {
  ApiFailureKind,
  ImagePreviewRouteParam,
  PostRouteParam,
  RepostListRouteParam,
  Result,
  UserRouteParam,
  WeiboMediaKind,
  WeiboPost
} from '../model/WeiboModels';
import { RouterConstants } from '../common/constants/RouterConstants';
import { CardGlowIntensity, CardGlowPalette } from '../common/constants/SettingsConstants';
import { appSettings } from '../model/AppSettings';
import { authViewModel } from '../viewmodel/AuthViewModel';
import { postInteractionViewModel } from '../viewmodel/PostInteractionViewModel';
import { notificationService } from '../service/NotificationService';
import { MaterialController } from '../service/MaterialController';
import { ThemeColorController } from '../service/ThemeColorController';
import { PostDateDisplay, PostDateFormatter, PostDateKind } from '../service/PostDateFormatter';
import { WeiboMediaGrid } from './WeiboMediaGrid';
import { WeiboMediaTile } from './WeiboMediaTile';
import { WeiboLiveCard } from './WeiboLiveCard';
import { common } from '@kit.AbilityKit';
import { MenuItemSpec, MenuSpec } from '../common/components/MenuSpec';
import { AppMenu } from '../common/components/AppMenu';
import { AppVideoPlayer } from '../common/components/AppVideoPlayer';
import { contentActionService } from '../service/ContentActionService';
import { SocialRichText } from '../common/components/SocialRichText';
import { socialEntityInteractionGuard } from '../service/SocialEntityInteractionGuard';

@ComponentV2
export struct WeiboPostCard {
  @Param post: WeiboPost = new WeiboPost();
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param expanded: boolean = false;
  @Param showMetrics: boolean = true;
  @Event onCommentRequested: () => void = (): void => {};
  @Local repostEditorVisible: boolean = false;
  @Local repostText: string = '';
  private suppressNextCardClick: boolean = false;

  aboutToAppear(): void {
    postInteractionViewModel.remember(this.post);
  }

  private openPost(focusComments: boolean = false): void {
    if (this.suppressNextCardClick || socialEntityInteractionGuard.blocked()) {
      return;
    }
    if (this.expanded) {
      if (focusComments) {
        this.onCommentRequested();
      }
      return;
    }
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_DETAIL,
      new PostRouteParam(this.post, focusComments)));
  }

  private openRepost(): void {
    if (this.suppressNextCardClick || socialEntityInteractionGuard.blocked()) {
      return;
    }
    const repost: WeiboPost | undefined = this.post.repost;
    if (repost === undefined || repost.id.length === 0) {
      return;
    }
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_DETAIL, new PostRouteParam(repost)));
  }

  private openUser(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_PROFILE,
      new UserRouteParam(this.post.user.id, this.post.user.name)));
  }

  private openReposts(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_REPOST_LIST,
      new RepostListRouteParam(this.post.id)));
  }

  private openImage(imageIndex: number): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_IMAGE_PREVIEW,
      new ImagePreviewRouteParam(this.post.media.imageUrls, imageIndex)));
  }

  private async openLive(): Promise<void> {
    this.suppressNextCardClick = true;
    setTimeout((): void => {
      this.suppressNextCardClick = false;
    }, 0);
    if (!await contentActionService.openLink(this.hostContext(), contentActionService.liveUrl(this.post))) {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_open_failed'));
    }
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private notifyCopy(success: boolean): void {
    if (success) {
      notificationService.showSuccess(this.getUIContext(), $r('app.string.notice_copied'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_copy_failed'));
    }
  }

  private async copyPostText(): Promise<void> {
    this.notifyCopy(await contentActionService.copy(this.post.text));
  }

  private async copyPostLink(): Promise<void> {
    this.notifyCopy(await contentActionService.copy(contentActionService.postUrl(this.post)));
  }

  private async sharePost(): Promise<void> {
    const success: boolean = await contentActionService.shareText(this.hostContext(), this.post.user.name,
      contentActionService.postShareText(this.post));
    if (!success) {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_share_failed'));
    }
  }

  private postMenuSpec(): MenuSpec {
    const items: MenuItemSpec[] = [];
    if (!this.expanded) {
      items.push(new MenuItemSpec('detail', $r('app.string.action_view_detail'), () => this.openPost()));
    }
    items.push(new MenuItemSpec('author', $r('app.string.action_view_author'), () => this.openUser()));
    items.push(new MenuItemSpec('copy-text', $r('app.string.action_copy_text'), () => this.copyPostText()));
    items.push(new MenuItemSpec('copy-link', $r('app.string.action_copy_link'), () => this.copyPostLink())
      .withEnabled(contentActionService.postUrl(this.post).length > 0));
    items.push(new MenuItemSpec('share', $r('app.string.action_share'), () => this.sharePost()));
    if (authViewModel.loggedIn) {
      items.push(new MenuItemSpec('favorite', postInteractionViewModel.favorited(this.post) ?
        $r('app.string.action_unfavorite') : $r('app.string.action_favorite'), () => this.toggleFavorite()));
    }
    if (authViewModel.userId.length > 0 && authViewModel.userId === this.post.user.id) {
      items.push(new MenuItemSpec('delete', $r('app.string.action_delete_post'), () => this.confirmDelete()));
    }
    return MenuSpec.fromItems(items);
  }

  @Builder
  PostMenu() {
    AppMenu(this.postMenuSpec());
  }

  private glowColor(): ResourceColor {
    if (appSettings.cardGlowPalette === CardGlowPalette.COOL) {
      return $r('app.color.hm_card_glow_cool');
    }
    if (appSettings.cardGlowPalette === CardGlowPalette.WARM) {
      return $r('app.color.hm_card_glow_warm');
    }
    return ThemeColorController.glow();
  }

  private glowRadius(): Resource {
    if (appSettings.cardGlowIntensity === CardGlowIntensity.VIVID) {
      return $r('app.float.card_glow_radius_vivid');
    }
    if (appSettings.cardGlowIntensity === CardGlowIntensity.STANDARD) {
      return $r('app.float.card_glow_radius_standard');
    }
    return $r('app.float.card_glow_radius_soft');
  }

  private createdAtText(): ResourceStr {
    const display: PostDateDisplay = this.expanded ? PostDateFormatter.full(this.post.createdAt) :
      PostDateFormatter.friendly(this.post.createdAt);
    if (display.kind === PostDateKind.JUST_NOW) {
      return $r('app.string.post_date_just_now');
    }
    if (display.kind === PostDateKind.MINUTES_AGO) {
      return $r('app.string.post_date_minutes_ago', display.first);
    }
    if (display.kind === PostDateKind.HOURS_AGO) {
      return $r('app.string.post_date_hours_ago', display.first);
    }
    if (display.kind === PostDateKind.YESTERDAY) {
      return $r('app.string.post_date_yesterday');
    }
    if (display.kind === PostDateKind.MONTH_DAY) {
      return $r('app.string.post_date_month_day', display.first, display.second);
    }
    if (display.kind === PostDateKind.YEAR_MONTH_DAY) {
      return $r('app.string.post_date_year_month_day', display.first, display.second, display.third);
    }
    if (display.kind === PostDateKind.FULL) {
      return $r('app.string.post_date_full', display.first, display.second, display.third,
        display.fourth, display.fifth);
    }
    return display.raw;
  }

  private repostMenu(): MenuElement[] {
    const immediate: MenuElement = {
      value: $r('app.string.action_repost_now'),
      action: () => this.submitRepost('')
    };
    const edit: MenuElement = {
      value: $r('app.string.action_repost_edit'),
      action: () => this.repostEditorVisible = true
    };
    const list: MenuElement = {
      value: $r('app.string.action_view_reposts'),
      action: () => this.openReposts()
    };
    return [immediate, edit, list];
  }

  private requireLogin(): boolean {
    if (authViewModel.loggedIn) {
      return true;
    }
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
    return false;
  }

  private async toggleLike(): Promise<void> {
    if (!this.requireLogin()) {
      return;
    }
    const result: Result<boolean> = await postInteractionViewModel.toggleLike(this.post);
    if (!result.success) {
      if (result.authRequired) {
        notificationService.showError(this.getUIContext(), $r('app.string.error_login_expired'));
      } else if (result.failureKind === ApiFailureKind.NETWORK) {
        notificationService.showError(this.getUIContext(), $r('app.string.mutation_result_unknown'));
      } else if (result.message.length > 0) {
        notificationService.showError(this.getUIContext(), result.message);
      } else {
        notificationService.showError(this.getUIContext(), $r('app.string.mutation_failed'));
      }
    }
  }

  private async submitRepost(content: string): Promise<void> {
    if (!this.requireLogin()) {
      return;
    }
    if (await postInteractionViewModel.repost(this.post, content)) {
      this.repostText = '';
      this.repostEditorVisible = false;
      notificationService.showSuccess(this.getUIContext(), $r('app.string.repost_sent'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.mutation_failed'));
    }
  }

  private async toggleFavorite(): Promise<void> {
    if (!this.requireLogin()) {
      return;
    }
    const result: Result<boolean> = await postInteractionViewModel.toggleFavorite(this.post);
    if (result.success) {
      notificationService.showSuccess(this.getUIContext(), postInteractionViewModel.favorited(this.post) ?
        $r('app.string.favorite_success') : $r('app.string.unfavorite_success'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.mutation_failed'));
    }
  }

  private confirmDelete(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.delete_post_title'),
      message: $r('app.string.delete_post_message'),
      primaryButton: { value: $r('app.string.action_cancel'), action: () => {} },
      secondaryButton: { value: $r('app.string.action_delete_post'), action: () => { this.deletePost(); } }
    });
  }

  private async deletePost(): Promise<void> {
    const result: Result<boolean> = await postInteractionViewModel.deletePost(this.post);
    if (result.success) {
      notificationService.showSuccess(this.getUIContext(), $r('app.string.delete_post_success'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.mutation_failed'));
    }
  }

  private canSendEditedRepost(): boolean {
    return this.repostText.trim().length > 0 && !postInteractionViewModel.pending(this.post.id);
  }

  private submitEditedRepost(): void {
    if (this.canSendEditedRepost()) {
      this.submitRepost(this.repostText);
    }
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
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: $r('app.float.space_s') }) {
          Text(this.createdAtText())
            .fontSize($r('app.float.font_size_caption'))
            .fontColor($r('app.color.hm_text_secondary'))
            .maxLines(1)
          if (this.post.source.length > 0) {
            Text(this.post.source)
              .fontSize($r('app.float.font_size_caption'))
              .fontColor($r('app.color.hm_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button() {
        SymbolGlyph($r('sys.symbol.ellipsis_circle'))
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('app.color.hm_text_secondary')])
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .width($r('app.float.button_height'))
      .height($r('app.float.button_height'))
      .accessibilityText($r('app.string.action_more'))
      .bindMenu(this.PostMenu(), MaterialController.menuOptions(appSettings.immersiveOn))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up) {
          event.stopPropagation();
        }
      })
    }
    .width('100%')
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Up) {
        event.stopPropagation();
      }
    })
    .onClick(() => this.openUser())
  }

  @Builder
  videoContent() {
    AppVideoPlayer({
      videoUrl: this.post.media.videoUrl,
      posterUrl: this.post.media.videoPosterUrl,
      playerHeight: $r('app.float.media_single_height'),
      playerRadius: $r('app.float.radius_small'),
      coordinateInlinePlayback: true,
      pauseWhenHidden: true
    })
  }

  @Builder
  imageContent() {
    if (this.post.media.imageUrls.length === 1) {
      WeiboMediaTile({
        imageUrl: this.post.media.imageUrls[0],
        imageIndex: 0,
        onOpen: (imageIndex: number) => this.openImage(imageIndex)
      })
        .height($r('app.float.media_single_height'))
    } else if (this.post.media.imageUrls.length === 2) {
      Row({ space: $r('app.float.media_grid_gap') }) {
        WeiboMediaTile({
          imageUrl: this.post.media.imageUrls[0],
          imageIndex: 0,
          onOpen: (imageIndex: number) => this.openImage(imageIndex)
        }).layoutWeight(1)
        WeiboMediaTile({
          imageUrl: this.post.media.imageUrls[1],
          imageIndex: 1,
          onOpen: (imageIndex: number) => this.openImage(imageIndex)
        }).layoutWeight(1)
      }
      .width('100%')
      .height($r('app.float.media_double_height'))
    } else if (this.post.media.imageUrls.length <= 3) {
      WeiboMediaGrid({
        imageUrls: this.post.media.imageUrls,
        gridHeight: $r('app.float.media_grid_row_height'),
        onOpen: (imageIndex: number) => this.openImage(imageIndex)
      })
    } else if (this.post.media.imageUrls.length <= 6) {
      WeiboMediaGrid({
        imageUrls: this.post.media.imageUrls,
        gridHeight: $r('app.float.media_grid_two_rows_height'),
        onOpen: (imageIndex: number) => this.openImage(imageIndex)
      })
    } else {
      WeiboMediaGrid({
        imageUrls: this.post.media.imageUrls,
        gridHeight: $r('app.float.media_grid_three_rows_height'),
        onOpen: (imageIndex: number) => this.openImage(imageIndex)
      })
    }
  }

  @Builder
  mediaContent() {
    if (this.post.media.kind === WeiboMediaKind.LIVE) {
      WeiboLiveCard({
        posterUrl: this.post.media.videoPosterUrl,
        title: this.post.media.pageTitle,
        state: this.post.media.liveState,
        onOpen: () => this.openLive()
      })
    } else if (this.post.media.videoUrl.length > 0) {
      this.videoContent()
    } else if (this.post.media.imageUrls.length > 0) {
      this.imageContent()
    }
  }

  @Builder
  repostContent() {
    if (this.post.repost) {
      Column({ space: $r('app.float.space_s') }) {
        Text($r('app.string.post_repost_author', this.post.repost.user.name))
          .fontSize($r('app.float.font_size_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColorController.brand())
          .width('100%')
        if (this.expanded) {
          SocialRichText({
            text: this.post.repost.text,
            entities: this.post.repost.textEntities,
            fontSize: $r('app.float.font_size_caption'),
            fontColor: $r('app.color.hm_text_secondary'),
            brandColor: ThemeColorController.brand(),
            navPathStack: this.navPathStack,
            onPlainTap: () => this.openRepost()
          })
        } else {
          SocialRichText({
            text: this.post.repost.text,
            entities: this.post.repost.textEntities,
            fontSize: $r('app.float.font_size_caption'),
            fontColor: $r('app.color.hm_text_secondary'),
            maxLines: 3,
            brandColor: ThemeColorController.brand(),
            navPathStack: this.navPathStack,
            onPlainTap: () => this.openRepost()
          })
        }
      }
      .width('100%')
      .padding($r('app.float.space_m'))
      .backgroundColor(ThemeColorController.soft())
      .borderRadius($r('app.float.radius_small'))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up) {
          event.stopPropagation();
        }
      })
      .onClick(() => this.openRepost())
    }
  }

  @Builder
  metricItem(symbol: Resource, label: ResourceStr, active: boolean) {
    Row({ space: $r('app.float.space_xs') }) {
      if (active) {
        SymbolGlyph(symbol)
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([ThemeColorController.brand()])
        Text(label)
          .fontSize($r('app.float.font_size_metric'))
          .fontColor(ThemeColorController.brand())
      } else {
        SymbolGlyph(symbol)
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('app.color.hm_text_secondary')])
        Text(label)
          .fontSize($r('app.float.font_size_metric'))
          .fontColor($r('app.color.hm_text_secondary'))
      }
    }
  }

  @Builder
  repostEditor() {
    if (this.repostEditorVisible) {
      Column({ space: $r('app.float.space_s') }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          TextArea({ text: this.repostText, placeholder: $r('app.string.repost_hint') })
            .onChange((value: string) => this.repostText = value)
            .maxLines(4, { overflowMode: MaxLinesMode.SCROLL })
            .padding({ right: $r('app.float.button_height') })
            .width('100%')
            .backgroundColor($r('app.color.hm_search_background'))
            .borderRadius($r('app.float.radius_small'))
          if (this.repostText.length > 0) {
            Button() {
              SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                .fontSize($r('app.float.icon_size_small'))
                .fontColor([$r('app.color.hm_text_secondary')])
            }
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .backgroundColor(Color.Transparent)
            .width($r('app.float.button_height'))
            .height($r('app.float.button_height'))
            .accessibilityText($r('app.string.action_clear_repost'))
            .onClick(() => this.repostText = '')
          }
        }
        .width('100%')
        Row({ space: $r('app.float.space_s') }) {
          Blank()
          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize($r('app.float.icon_size_small'))
              .fontColor([$r('app.color.hm_text_secondary')])
          }
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .backgroundColor(Color.Transparent)
            .width($r('app.float.button_height'))
            .height($r('app.float.button_height'))
            .accessibilityText($r('app.string.action_cancel'))
            .onClick(() => {
              this.repostEditorVisible = false;
              this.repostText = '';
            })
          Button() {
            SymbolGlyph($r('sys.symbol.paperplane_fill'))
              .fontSize($r('app.float.icon_size_small'))
              .fontColor([this.canSendEditedRepost()
                ? ThemeColorController.brand() : $r('app.color.hm_text_secondary')])
          }
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .backgroundColor(Color.Transparent)
            .width($r('app.float.button_height'))
            .height($r('app.float.button_height'))
            .enabled(this.canSendEditedRepost())
            .accessibilityText($r('app.string.action_repost_send'))
            .onClick(() => this.submitEditedRepost())
        }
        .width('100%')
      }
      .width('100%')
      .padding($r('app.float.space_m'))
      .backgroundColor($r('app.color.hm_card_background'))
      .borderRadius($r('app.float.radius_small'))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up) {
          event.stopPropagation();
        }
      })
    }
  }

  @Builder
  metrics() {
    Row() {
      Button() {
        this.metricItem($r('sys.symbol.repeat'),
          $r('app.string.post_reposts', postInteractionViewModel.repostsCount(this.post)), false)
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .enabled(!postInteractionViewModel.pending(this.post.id))
      .accessibilityText($r('app.string.action_repost'))
      .bindMenu(this.repostMenu(), MaterialController.menuOptions(appSettings.immersiveOn))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up) {
          event.stopPropagation();
        }
      })
      Button() {
        this.metricItem($r('sys.symbol.ellipsis_bubble'),
          $r('app.string.post_comments', this.post.commentsCount), false)
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .accessibilityText($r('app.string.post_comments', this.post.commentsCount))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up) {
          event.stopPropagation();
        }
      })
      .onClick(() => this.openPost(true))
      Button() {
        if (postInteractionViewModel.liked(this.post)) {
          this.metricItem($r('sys.symbol.heart_fill'),
            $r('app.string.post_likes', postInteractionViewModel.likesCount(this.post)), true)
        } else {
          this.metricItem($r('sys.symbol.heart'),
            $r('app.string.post_likes', postInteractionViewModel.likesCount(this.post)), false)
        }
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .enabled(!postInteractionViewModel.pending(this.post.id))
      .accessibilityText(postInteractionViewModel.liked(this.post)
        ? $r('app.string.action_unlike') : $r('app.string.action_like'))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up) {
          event.stopPropagation();
        }
      })
      .onClick(() => this.toggleLike())
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  bodyText() {
    if (this.expanded) {
      SocialRichText({
        text: this.post.text,
        entities: this.post.textEntities,
        brandColor: ThemeColorController.brand(),
        navPathStack: this.navPathStack,
        onPlainTap: () => this.openPost()
      })
    } else {
      SocialRichText({
        text: this.post.text,
        entities: this.post.textEntities,
        maxLines: 4,
        brandColor: ThemeColorController.brand(),
        navPathStack: this.navPathStack,
        onPlainTap: () => this.openPost()
      })
      if (this.post.isLongText || this.post.text.length > 120) {
        Text($r('app.string.post_read_more'))
          .fontSize($r('app.float.font_size_caption'))
          .fontColor(ThemeColorController.brand())
      }
    }
  }

  build() {
    if (!postInteractionViewModel.deleted(this.post)) {
      Stack() {
      Column({ space: $r('app.float.space_m') }) {
        this.userHeader()
        this.bodyText()
        this.mediaContent()
        this.repostContent()
        this.repostEditor()
        if (this.expanded && this.post.fullTextUnavailable) {
          Text($r('app.string.post_full_text_unavailable'))
            .fontSize($r('app.float.font_size_caption'))
            .fontColor($r('app.color.hm_error'))
            .width('100%')
        }
        if (this.showMetrics) {
          Divider().color($r('app.color.hm_divider'))
          this.metrics()
        }
      }
      .width('100%')
      .padding($r('app.float.space_l'))
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor(appSettings.cardGlowEnabled
      ? $r('app.color.hm_card_glass') : $r('app.color.hm_card_background'))
    .backdropBlur(appSettings.cardGlowEnabled ? BlurStyle.COMPONENT_ULTRA_THIN : 0)
    .shadow({
      radius: appSettings.cardGlowEnabled ? this.glowRadius() : 0,
      color: appSettings.cardGlowEnabled ? this.glowColor() : Color.Transparent,
      offsetX: 0,
      offsetY: $r('app.float.card_glow_shadow_offset')
    })
    .borderRadius($r('app.float.radius_card'))
    .bindContextMenu(this.PostMenu(), ResponseType.LongPress)
      .onClick(() => this.openPost())
    }
  }
}
