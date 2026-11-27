import { AnimatedImageService } from '../service/AnimatedImageService';
import { AnimatedNetworkImage } from './AnimatedNetworkImage';

@ComponentV2
export struct WeiboMediaTile {
  @Param imageUrl: string = '';
  @Param imageIndex: number = 0;
  @Param remainingCount: number = 0;
  @Event onOpen: (imageIndex: number) => void = (imageIndex: number): void => {};
  @Local loadFailed: boolean = false;
  @Local imageVisible: boolean = false;

  private openImage(): void {
    this.onOpen(this.imageIndex);
  }

  private retry(): void {
    this.loadFailed = false;
  }

  private shouldAnimate(): boolean {
    return this.imageVisible && AnimatedImageService.isCandidate(this.imageUrl);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.loadFailed || this.imageUrl.length === 0) {
        Column({ space: $r('app.float.space_s') }) {
          Text($r('app.string.media_load_failed'))
            .fontSize($r('app.float.font_size_caption'))
            .fontColor($r('app.color.hm_text_secondary'))
          Button($r('app.string.image_retry'))
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .onClick(() => this.retry())
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.hm_media_placeholder'))
      } else {
        if (this.shouldAnimate()) {
          AnimatedNetworkImage({
            imageUrl: this.imageUrl,
            fitMode: ImageFit.Cover,
            maxSidePx: 360,
            memoryBudgetBytes: 12 * 1024 * 1024,
            onTap: () => this.openImage(),
            onLoadFailed: () => this.loadFailed = true
          })
        } else {
          Image(this.imageUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .onError((_error: ImageError) => this.loadFailed = true)
            .onClick(() => this.openImage())
        }
      }
      if (this.remainingCount > 0) {
        Text($r('app.string.post_image_more', this.remainingCount))
          .fontSize($r('app.float.font_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.white'))
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.hm_scrim'))
          .onClick(() => this.openImage())
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .borderRadius($r('app.float.radius_small'))
    .onVisibleAreaChange([0.0, 0.25], (isVisible: boolean, currentRatio: number) => {
      this.imageVisible = isVisible && currentRatio >= 0.25;
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Up) {
        event.stopPropagation();
      }
    })
  }
}
