import { ImagePreviewRouteParam } from '../model/WeiboModels';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';
import { common } from '@kit.AbilityKit';
import { AppMenu } from '../common/components/AppMenu';
import { MediaActionOverlay } from '../common/components/MediaActionOverlay';
import { MenuItemSpec, MenuSpec } from '../common/components/MenuSpec';
import { appSettings } from '../model/AppSettings';
import { contentActionService } from '../service/ContentActionService';
import {
  mediaActionService,
  MediaActionController,
  MediaActionKind,
  MediaActionResult
} from '../service/MediaActionService';
import { MaterialController } from '../service/MaterialController';
import { ThemeColorController } from '../service/ThemeColorController';
import { notificationService } from '../service/NotificationService';
import { HdsBarWidthRangeOptions, HdsTabs, HdsTabsFloatingStyle } from '@kit.UIDesignKit';
import { AnimatedImageService } from '../service/AnimatedImageService';
import { AnimatedNetworkImage } from './AnimatedNetworkImage';

@ComponentV2
struct WeiboPreviewImageItem {
  @Param imageUrl: string = '';
  @Param animationEnabled: boolean = false;
  @Event onTap: () => void = (): void => {};
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

  private toggleZoom(): void {
    this.imageScale = this.imageScale > 1
      ? 1 : CommonConstants.IMAGE_PREVIEW_DOUBLE_TAP_SCALE;
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
        if (this.animationEnabled && AnimatedImageService.isCandidate(this.imageUrl)) {
          AnimatedNetworkImage({
            imageUrl: this.imageUrl,
            fitMode: ImageFit.Contain,
            maxSidePx: 720,
            memoryBudgetBytes: 48 * 1024 * 1024,
            onLoadFailed: () => this.loadFailed = true
          })
            .scale({ x: this.imageScale, y: this.imageScale })
            .gesture(
              GestureGroup(GestureMode.Exclusive,
                TapGesture({ count: 2 })
                  .onAction((_event: GestureEvent) => this.toggleZoom()),
                TapGesture({ count: 1 })
                  .onAction((_event: GestureEvent) => this.onTap())
              )
            )
            .parallelGesture(
              PinchGesture({ fingers: 2 })
                .onActionStart((event: GestureEvent) => this.startPinch(event))
                .onActionUpdate((event: GestureEvent) => this.updatePinch(event))
            )
        } else {
          Image(this.imageUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.imageScale, y: this.imageScale })
            .onError((_error: ImageError) => this.loadFailed = true)
            .gesture(
              GestureGroup(GestureMode.Exclusive,
                TapGesture({ count: 2 })
                  .onAction((_event: GestureEvent) => this.toggleZoom()),
                TapGesture({ count: 1 })
                  .onAction((_event: GestureEvent) => this.onTap())
              )
            )
            .parallelGesture(
              PinchGesture({ fingers: 2 })
                .onActionStart((event: GestureEvent) => this.startPinch(event))
                .onActionUpdate((event: GestureEvent) => this.updatePinch(event))
            )
        }
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}

@ComponentV2
export struct ImagePreviewTitle {
  @Param routeParam: ImagePreviewRouteParam = new ImagePreviewRouteParam([], 0);
  @Param currentIndex: number = 0;
  @Param mediaActions: MediaActionController = new MediaActionController();

  private currentUrl(): string {
    return this.routeParam.imageUrls[this.currentIndex] ?? '';
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private notifyResult(result: MediaActionResult, isShare: boolean = false): void {
    if (result.success) {
      if (!isShare) {
        notificationService.showSuccess(this.getUIContext(), $r('app.string.notice_media_saved'));
      }
    } else if (result.cancelled) {
      notificationService.showInfo(this.getUIContext(), $r('app.string.notice_media_cancelled'));
    } else {
      notificationService.showError(this.getUIContext(), isShare && result.message === 'share'
        ? $r('app.string.notice_share_failed') : $r('app.string.notice_media_failed'));
    }
  }

  private async saveImage(): Promise<void> {
    this.notifyResult(await mediaActionService.save(this.hostContext(), this.mediaActions,
      this.currentUrl(), MediaActionKind.IMAGE));
  }

  private async shareImage(): Promise<void> {
    this.notifyResult(await mediaActionService.share(this.hostContext(), this.mediaActions,
      this.currentUrl(), MediaActionKind.IMAGE), true);
  }

  private async copyImageLink(): Promise<void> {
    const success: boolean = await contentActionService.copy(this.currentUrl());
    if (success) {
      notificationService.showSuccess(this.getUIContext(), $r('app.string.notice_copied'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_copy_failed'));
    }
  }

  private async openImageLink(): Promise<void> {
    if (!await contentActionService.openLink(this.hostContext(), this.currentUrl())) {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_open_failed'));
    }
  }

  private imageMenuSpec(): MenuSpec {
    const available: boolean = this.currentUrl().length > 0 && !this.mediaActions.busy();
    return MenuSpec.fromItems([
      new MenuItemSpec('save-image', $r('app.string.action_save_image'), () => this.saveImage())
        .withEnabled(available),
      new MenuItemSpec('share-image', $r('app.string.action_share_image'), () => this.shareImage())
        .withEnabled(available),
      new MenuItemSpec('copy-image-link', $r('app.string.action_copy_link'), () => this.copyImageLink())
        .withEnabled(available),
      new MenuItemSpec('open-image-link', $r('app.string.action_open_browser'), () => this.openImageLink())
        .withEnabled(available)
    ]);
  }

  @Builder
  ImageMenu() {
    AppMenu(this.imageMenuSpec());
  }

  build() {
    Row() {
      Blank().width($r('app.float.preview_control_size'))
      Blank()
      Text($r('app.string.image_preview_position', this.currentIndex + 1, this.routeParam.imageUrls.length))
        .fontSize($r('app.float.font_size_caption'))
        .fontColor($r('sys.color.white'))
        .textShadow({ radius: 3, color: '#B3000000', offsetX: 0, offsetY: 1 })
      Blank()
      Button() {
        SymbolGlyph($r('sys.symbol.ellipsis_circle'))
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('sys.color.white')])
      }
      .width($r('app.float.preview_control_size'))
      .height($r('app.float.preview_control_size'))
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.action_more'))
      .bindMenu(this.ImageMenu(), MaterialController.menuOptions(appSettings.immersiveOn))
    }
    .width('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
  }
}

@ComponentV2
export struct ImagePreviewView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: ImagePreviewRouteParam = new ImagePreviewRouteParam([], 0);
  @Param controlsVisible: boolean = true;
  @Param mediaActions: MediaActionController = new MediaActionController();
  @Event onIndexChange: (index: number) => void = (_index: number): void => {};
  @Event onControlsVisibleChange: (visible: boolean) => void = (_visible: boolean): void => {};
  @Local currentIndex: number = 0;
  @Local previewActive: boolean = true;
  private swiperController: SwiperController = new SwiperController();

  aboutToAppear(): void {
    this.currentIndex = this.routeParam.initialIndex;
    this.onIndexChange(this.currentIndex);
    this.onControlsVisibleChange(true);
    this.previewActive = true;
  }

  aboutToDisappear(): void {
    this.previewActive = false;
    this.mediaActions.cancel();
  }

  private close(): void {
    this.navPathStack.pop();
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private currentUrl(): string {
    if (this.currentIndex < 0 || this.currentIndex >= this.routeParam.imageUrls.length) {
      return '';
    }
    return this.routeParam.imageUrls[this.currentIndex];
  }

  private toggleControls(): void {
    this.onControlsVisibleChange(!this.controlsVisible);
  }

  private bottomBarStyle(): HdsTabsFloatingStyle {
    const width: Resource = $r('app.float.preview_action_bar_width');
    const barWidth: HdsBarWidthRangeOptions = {
      smallWidth: width,
      mediumWidth: width,
      largeWidth: width
    };
    const style: HdsTabsFloatingStyle = {
      barWidth: barWidth,
      barBottomMargin: safeArea.bottomInsetVp,
      gradientMask: { maskColor: Color.Transparent },
      lightColor: ThemeColorController.brand(),
      systemMaterialEffect: MaterialController.params(appSettings.materialType,
        appSettings.materialLevel, appSettings.immersiveOn && this.controlsVisible)
    };
    return style;
  }

  private notifyMediaResult(result: MediaActionResult, isShare: boolean = false): void {
    if (result.success) {
      if (!isShare) {
        notificationService.showSuccess(this.getUIContext(), $r('app.string.notice_media_saved'));
      }
      return;
    }
    if (result.cancelled) {
      notificationService.showInfo(this.getUIContext(), $r('app.string.notice_media_cancelled'));
      return;
    }
    notificationService.showError(this.getUIContext(), isShare && result.message === 'share'
      ? $r('app.string.notice_share_failed') : $r('app.string.notice_media_failed'));
  }

  private async saveImage(): Promise<void> {
    this.notifyMediaResult(await mediaActionService.save(this.hostContext(), this.mediaActions,
      this.currentUrl(), MediaActionKind.IMAGE));
  }

  @Builder
  PreviewContent() {
    if (this.routeParam.imageUrls.length > 0) {
      Swiper(this.swiperController) {
        ForEach(this.routeParam.imageUrls, (imageUrl: string, imageIndex: number) => {
          WeiboPreviewImageItem({
            imageUrl: imageUrl,
            animationEnabled: this.previewActive && imageIndex === this.currentIndex,
            onTap: () => this.toggleControls()
          })
        }, (imageUrl: string, imageIndex: number) => imageUrl + imageIndex.toString())
      }
      .width('100%')
      .height('100%')
      .index(this.routeParam.initialIndex)
      .indicator(false)
      .loop(false)
      .onChange((imageIndex: number) => {
        this.mediaActions.cancel();
        this.currentIndex = imageIndex;
        this.onIndexChange(imageIndex);
      })
    } else {
      Text($r('app.string.media_load_failed'))
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('sys.color.white'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .height('100%')
    }
  }

  @Builder
  BottomBarBackdrop() {
    Row()
      .width('100%')
      .height(this.controlsVisible ? $r('app.float.preview_action_bar_height') : 0)
  }

  @Builder
  PreviewTabs() {
    HdsTabs() {
      TabContent() {
        this.PreviewContent()
      }
      .tabBar(this.BottomBarBackdrop())
    }
    .barPosition(BarPosition.End)
    .barOverlap(true)
    .barHeight(this.controlsVisible ? $r('app.float.preview_action_bar_height') : 0)
    .scrollable(false)
    .barBackgroundColor(this.controlsVisible ? $r('app.color.hm_preview_control') : Color.Transparent)
    .barFloatingStyle(this.bottomBarStyle())
    .width('100%')
    .height('100%')
  }

  @Builder
  BottomControls() {
    Row({ space: $r('app.float.space_l') }) {
      Button() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize($r('app.float.action_glass_icon_size'))
          .fontColor([ThemeColorController.brand()])
      }
      .width($r('app.float.action_glass_size'))
      .height($r('app.float.action_glass_size'))
      .padding(0)
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.action_close'))
      .onClick(() => this.close())
      .id('image-preview-close')
      Button() {
        SymbolGlyph($r('sys.symbol.square_and_arrow_down'))
          .fontSize($r('app.float.action_glass_icon_size'))
          .fontColor([this.currentUrl().length === 0 || this.mediaActions.busy()
            ? $r('app.color.hm_text_secondary') : ThemeColorController.brand()])
      }
      .width($r('app.float.action_glass_size'))
      .height($r('app.float.action_glass_size'))
      .padding(0)
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.action_save_image'))
      .enabled(this.currentUrl().length > 0 && !this.mediaActions.busy())
      .onClick(() => this.saveImage())
      .id('image-preview-save')
    }
    .width($r('app.float.preview_action_bar_width'))
    .height($r('app.float.preview_action_bar_height'))
    .justifyContent(FlexAlign.Center)
    .margin({ bottom: safeArea.bottomInsetVp })
  }

  @Builder
  ControlsOverlay() {
    Column() {
      Blank()
      this.BottomControls()
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.PreviewTabs()
      if (this.controlsVisible) {
        this.ControlsOverlay()
      }
      if (this.mediaActions.busy()) {
        MediaActionOverlay({
          controller: this.mediaActions,
          onCancel: () => this.mediaActions.cancel()
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hm_video_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
