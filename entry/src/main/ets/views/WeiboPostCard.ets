import {
  ImagePreviewRouteParam,
  PostRouteParam,
  UserRouteParam,
  VideoRouteParam,
  WeiboPost
} from '../model/WeiboModels';
import { RouterConstants } from '../common/constants/RouterConstants';
import { CardGlowIntensity, CardGlowPalette } from '../common/constants/SettingsConstants';
import { appSettings } from '../model/AppSettings';
import { WeiboMediaGrid } from './WeiboMediaGrid';
import { WeiboMediaTile } from './WeiboMediaTile';

@ComponentV2
export struct WeiboPostCard {
  @Param post: WeiboPost = new WeiboPost();
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param expanded: boolean = false;
  @Param useAppGlowSettings: boolean = true;
  @Param customGlowEnabled: boolean = true;
  @Param customGlowBaseColor: ResourceColor = $r('app.color.hm_card_background');
  @Param customGlowColor: ResourceColor = $r('app.color.hm_card_glow_theme');
  @Param customGlowRadius: Length = $r('app.float.card_glow_radius_soft');
  @Param customGlowCenterX: Length = $r('app.float.card_glow_center_x');
  @Param customGlowCenterY: Length = $r('app.float.card_glow_center_y');

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

  private openImage(imageIndex: number): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_IMAGE_PREVIEW,
      new ImagePreviewRouteParam(this.post.media.imageUrls, imageIndex)));
  }

  private glowEnabled(): boolean {
    return this.useAppGlowSettings ? appSettings.cardGlowEnabled : this.customGlowEnabled;
  }

  private glowColor(): ResourceColor {
    if (!this.useAppGlowSettings) {
      return this.customGlowColor;
    }
    if (appSettings.cardGlowPalette === CardGlowPalette.COOL) {
      return $r('app.color.hm_card_glow_cool');
    }
    if (appSettings.cardGlowPalette === CardGlowPalette.WARM) {
      return $r('app.color.hm_card_glow_warm');
    }
    return $r('app.color.hm_card_glow_theme');
  }

  private glowPaintColor(): ResourceColor {
    if (this.glowEnabled()) {
      return this.glowColor();
    }
    return Color.Transparent;
  }

  private glowBaseColor(): ResourceColor {
    if (this.useAppGlowSettings) {
      return $r('app.color.hm_card_background');
    }
    return this.customGlowBaseColor;
  }

  private glowRadius(): Length {
    if (!this.useAppGlowSettings) {
      return this.customGlowRadius;
    }
    if (appSettings.cardGlowIntensity === CardGlowIntensity.VIVID) {
      return $r('app.float.card_glow_radius_vivid');
    }
    if (appSettings.cardGlowIntensity === CardGlowIntensity.STANDARD) {
      return $r('app.float.card_glow_radius_standard');
    }
    return $r('app.float.card_glow_radius_soft');
  }

  private glowCenterX(): Length {
    return this.useAppGlowSettings ? $r('app.float.card_glow_center_x') : this.customGlowCenterX;
  }

  private glowCenterY(): Length {
    return this.useAppGlowSettings ? $r('app.float.card_glow_center_y') : this.customGlowCenterY;
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
          Text(this.post.createdAt)
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
    Stack({ alignContent: Alignment.Center }) {
      if (this.post.media.videoPosterUrl.length > 0) {
        Image(this.post.media.videoPosterUrl)
          .width('100%')
          .height($r('app.float.media_single_height'))
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width('100%')
          .height($r('app.float.media_single_height'))
          .backgroundColor($r('app.color.hm_media_placeholder'))
      }
      Button() {
        SymbolGlyph($r('sys.symbol.play_round_rectangle_fill'))
          .fontSize($r('app.float.hero_icon_size'))
          .fontColor([$r('sys.color.white')])
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor($r('app.color.hm_scrim'))
      .accessibilityText($r('app.string.action_play_video'))
      .onClick(() => this.openVideo())
    }
    .width('100%')
    .height($r('app.float.media_single_height'))
    .clip(true)
    .borderRadius($r('app.float.radius_small'))
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Up) {
        event.stopPropagation();
      }
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
    if (this.post.media.videoUrl.length > 0) {
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
          .fontColor($r('app.color.hm_brand'))
          .width('100%')
        if (this.expanded) {
          Text(this.post.repost.text)
            .fontSize($r('app.float.font_size_caption'))
            .fontColor($r('app.color.hm_text_secondary'))
            .maxLines(8)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        } else {
          Text(this.post.repost.text)
            .fontSize($r('app.float.font_size_caption'))
            .fontColor($r('app.color.hm_text_secondary'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .width('100%')
      .padding($r('app.float.space_m'))
      .backgroundColor($r('app.color.hm_brand_soft'))
      .borderRadius($r('app.float.radius_small'))
    }
  }

  @Builder
  metricItem(symbol: Resource, label: ResourceStr, active: boolean) {
    Row({ space: $r('app.float.space_xs') }) {
      if (active) {
        SymbolGlyph(symbol)
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('app.color.hm_brand')])
        Text(label)
          .fontSize($r('app.float.font_size_metric'))
          .fontColor($r('app.color.hm_brand'))
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
  metrics() {
    Row() {
      this.metricItem($r('sys.symbol.repeat'), $r('app.string.post_reposts', this.post.repostsCount), false)
      this.metricItem($r('sys.symbol.ellipsis_bubble'), $r('app.string.post_comments', this.post.commentsCount), false)
      if (this.post.liked) {
        this.metricItem($r('sys.symbol.heart_fill'), $r('app.string.post_likes', this.post.likesCount), true)
      } else {
        this.metricItem($r('sys.symbol.heart'), $r('app.string.post_likes', this.post.likesCount), false)
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  bodyText() {
    if (this.expanded) {
      Text(this.post.text)
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_primary'))
        .lineHeight($r('app.float.space_xl'))
        .width('100%')
    } else {
      Text(this.post.text)
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_primary'))
        .lineHeight($r('app.float.space_xl'))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (this.post.text.length > 120) {
        Text($r('app.string.post_read_more'))
          .fontSize($r('app.float.font_size_caption'))
          .fontColor($r('app.color.hm_brand'))
      }
    }
  }

  build() {
    Stack() {
      Column({ space: $r('app.float.space_m') }) {
        this.userHeader()
        this.bodyText()
        this.mediaContent()
        this.repostContent()
        Divider().color($r('app.color.hm_divider'))
        this.metrics()
      }
      .width('100%')
      .padding($r('app.float.space_l'))
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor(this.glowBaseColor())
    .radialGradient({
      center: [this.glowCenterX(), this.glowCenterY()],
      radius: this.glowRadius(),
      colors: [[this.glowPaintColor(), 0.0], [Color.Transparent, 1.0]],
      repeating: false
    })
    .borderRadius($r('app.float.radius_card'))
    .clip(true)
    .onClick(() => this.openPost())
  }
}
