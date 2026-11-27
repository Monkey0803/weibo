import { WeiboLiveState } from '../model/WeiboModels';

@ComponentV2
export struct WeiboLiveCard {
  @Param posterUrl: string = '';
  @Param title: string = '';
  @Param state: WeiboLiveState = WeiboLiveState.UNKNOWN;
  @Event onOpen: () => void = (): void => {};
  @Local posterFailed: boolean = false;

  private stateLabel(): Resource {
    if (this.state === WeiboLiveState.ACTIVE) {
      return $r('app.string.live_state_active');
    }
    if (this.state === WeiboLiveState.ENDED) {
      return $r('app.string.live_state_ended');
    }
    return $r('app.string.live_state_unknown');
  }

  private stateColor(): ResourceColor {
    if (this.state === WeiboLiveState.ACTIVE) {
      return $r('app.color.hm_live_active');
    }
    if (this.state === WeiboLiveState.ENDED) {
      return $r('app.color.hm_live_ended');
    }
    return $r('app.color.hm_live_unknown');
  }

  private accessibilityLabel(): Resource {
    if (this.state === WeiboLiveState.ACTIVE) {
      return $r('app.string.live_accessibility_active');
    }
    if (this.state === WeiboLiveState.ENDED) {
      return $r('app.string.live_accessibility_ended');
    }
    return $r('app.string.live_accessibility_unknown');
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.posterUrl.length > 0 && !this.posterFailed) {
        Image(this.posterUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .onError((_error: ImageError) => this.posterFailed = true)
      } else {
        Column({ space: $r('app.float.space_s') }) {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize($r('app.float.icon_size'))
            .fontColor([$r('sys.color.white')])
          Text($r('app.string.live_placeholder'))
            .fontSize($r('app.float.font_size_caption'))
            .fontColor($r('sys.color.white'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.hm_live_unknown'))
      }

      Column() {
        Blank()
        if (this.title.length > 0) {
          Text(this.title)
            .fontSize($r('app.float.font_size_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.white'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .padding($r('app.float.space_m'))
      .linearGradient({
        angle: 0,
        colors: [[$r('app.color.hm_preview_control'), 0.0], [Color.Transparent, 0.6]]
      })

      Row({ space: $r('app.float.space_xs') }) {
        Text('●')
          .fontSize($r('app.float.font_size_metric'))
          .fontColor($r('sys.color.white'))
        Text(this.stateLabel())
          .fontSize($r('app.float.font_size_metric'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.white'))
      }
      .padding({
        left: $r('app.float.space_s'),
        right: $r('app.float.space_s'),
        top: $r('app.float.space_xs'),
        bottom: $r('app.float.space_xs')
      })
      .margin($r('app.float.space_m'))
      .backgroundColor(this.stateColor())
      .borderRadius($r('app.float.radius_small'))
      .align(Alignment.TopStart)

      Row({ space: $r('app.float.space_s') }) {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('sys.color.white')])
        Text($r('app.string.action_watch_on_weibo'))
          .fontSize($r('app.float.font_size_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.white'))
      }
      .padding({
        left: $r('app.float.space_m'),
        right: $r('app.float.space_m'),
        top: $r('app.float.space_s'),
        bottom: $r('app.float.space_s')
      })
      .backgroundColor($r('app.color.hm_preview_control'))
      .borderRadius($r('app.float.radius_small'))
    }
    .width('100%')
    .height($r('app.float.media_single_height'))
    .clip(true)
    .borderRadius($r('app.float.radius_small'))
    .accessibilityText(this.accessibilityLabel())
    .onClick(() => this.onOpen())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Up) {
        event.stopPropagation();
      }
    })
  }
}
