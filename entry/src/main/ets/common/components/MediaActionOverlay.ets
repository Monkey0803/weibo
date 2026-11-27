import { MediaActionController, MediaActionStage } from '../../service/MediaActionService';
import { ThemeColorController } from '../../service/ThemeColorController';

@ComponentV2
export struct MediaActionOverlay {
  @Param controller: MediaActionController = new MediaActionController();
  @Event onCancel: () => void = (): void => {};

  private progressText(): ResourceStr {
    if (this.controller.stage === MediaActionStage.CONNECTING || this.controller.totalBytes <= 0) {
      return $r('app.string.media_connecting');
    }
    return $r('app.string.media_downloading', this.controller.progressPercent());
  }

  build() {
    Column({ space: $r('app.float.space_m') }) {
      LoadingProgress()
        .width($r('app.float.progress_size'))
        .height($r('app.float.progress_size'))
      Text(this.progressText())
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('sys.color.white'))
      Button() {
        SymbolGlyph($r('sys.symbol.stop_circle'))
          .fontSize($r('app.float.icon_size'))
          .fontColor([ThemeColorController.brand()])
      }
        .width($r('app.float.preview_control_size'))
        .height($r('app.float.preview_control_size'))
        .padding(0)
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.action_cancel'))
        .onClick(() => this.onCancel())
    }
    .padding($r('app.float.space_l'))
    .backgroundColor($r('app.color.hm_scrim'))
    .borderRadius($r('app.float.radius_card'))
  }
}
