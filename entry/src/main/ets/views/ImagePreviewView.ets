import { ImagePreviewRouteParam } from '../model/WeiboModels';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';

@ComponentV2
struct WeiboPreviewImageItem {
  @Param imageUrl: string = '';
  @Local loadFailed: boolean = false;
  @Local imageScale: number = 1;
  @Local scaleAtStart: number = 1;

  private startPinch(_event: GestureEvent): void {
    this.scaleAtStart = this.imageScale;
  }

  private updatePinch(event: GestureEvent): void {
    const nextScale: number = this.scaleAtStart * event.scale;
    if (nextScale < 1) {
      this.imageScale = 1;
    } else if (nextScale > CommonConstants.IMAGE_PREVIEW_MAX_SCALE) {
      this.imageScale = CommonConstants.IMAGE_PREVIEW_MAX_SCALE;
    } else {
      this.imageScale = nextScale;
    }
  }

  private retry(): void {
    this.loadFailed = false;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.loadFailed || this.imageUrl.length === 0) {
        Column({ space: $r('app.float.space_m') }) {
          Text($r('app.string.media_load_failed'))
            .fontSize($r('app.float.font_size_body'))
            .fontColor($r('sys.color.white'))
          Button($r('app.string.image_retry'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(() => this.retry())
        }
      } else {
        Image(this.imageUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .scale({ x: this.imageScale, y: this.imageScale })
          .onError((_error: ImageError) => this.loadFailed = true)
          .gesture(
            PinchGesture({ fingers: 2 })
              .onActionStart((event: GestureEvent) => this.startPinch(event))
              .onActionUpdate((event: GestureEvent) => this.updatePinch(event))
          )
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}

@ComponentV2
export struct ImagePreviewView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: ImagePreviewRouteParam = new ImagePreviewRouteParam([], 0);
  @Local currentIndex: number = 0;
  private swiperController: SwiperController = new SwiperController();

  aboutToAppear(): void {
    this.currentIndex = this.routeParam.initialIndex;
  }

  private close(): void {
    this.navPathStack.pop();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.routeParam.imageUrls.length > 0) {
        Swiper(this.swiperController) {
          ForEach(this.routeParam.imageUrls, (imageUrl: string, imageIndex: number) => {
            WeiboPreviewImageItem({ imageUrl: imageUrl })
          }, (imageUrl: string, imageIndex: number) => imageUrl + imageIndex.toString())
        }
        .width('100%')
        .height('100%')
        .index(this.routeParam.initialIndex)
        .indicator(false)
        .loop(false)
        .onChange((imageIndex: number) => this.currentIndex = imageIndex)
      } else {
        Column({ space: $r('app.float.space_m') }) {
          Text($r('app.string.media_load_failed'))
            .fontSize($r('app.float.font_size_body'))
            .fontColor($r('sys.color.white'))
          Button($r('app.string.image_preview_back'))
            .onClick(() => this.close())
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
      Column() {
        Row().height(safeArea.topInsetVp)
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_backward'))
              .fontSize($r('app.float.icon_size'))
              .fontColor([$r('sys.color.white')])
          }
          .width($r('app.float.preview_control_size'))
          .height($r('app.float.preview_control_size'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .backgroundColor($r('app.color.hm_preview_control'))
          .accessibilityText($r('app.string.image_preview_back'))
          .onClick(() => this.close())
          Blank()
          if (this.routeParam.imageUrls.length > 0) {
            Text($r('app.string.image_preview_position', this.currentIndex + 1, this.routeParam.imageUrls.length))
              .fontSize($r('app.float.font_size_caption'))
              .fontColor($r('sys.color.white'))
              .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
              .height($r('app.float.preview_control_size'))
              .backgroundColor($r('app.color.hm_preview_control'))
              .borderRadius($r('app.float.preview_control_size'))
          }
        }
        .width('100%')
        .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hm_video_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
