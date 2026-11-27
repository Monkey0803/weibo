import { NoticeKind, noticeIcon } from '../../service/NotificationService';
import { ThemeColorController } from '../../service/ThemeColorController';

/** 非模态即时反馈的内容；系统弹窗背板负责沉浸光感。 */
@ComponentV2
export struct AppNoticeBar {
  @Param message: ResourceStr = '';
  @Param kind: NoticeKind = NoticeKind.INFO;
  @Param actionText: ResourceStr | undefined = undefined;
  @Event onAction: () => void = (): void => {};
  @Event onClose: () => void = (): void => {};

  private iconColor(): ResourceColor {
    if (this.kind === NoticeKind.ERROR) {
      return $r('app.color.hm_error');
    }
    return this.kind === NoticeKind.SUCCESS ? ThemeColorController.brand() : $r('app.color.hm_text_primary');
  }

  build() {
    Row({ space: $r('app.float.space_m') }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(noticeIcon(this.kind))
          .fontSize($r('app.float.icon_size'))
          .fontColor([this.iconColor()])
      }
      .width($r('app.float.preview_control_size'))
      .height($r('app.float.preview_control_size'))
      Text(this.message)
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (this.actionText !== undefined) {
        Button(this.actionText)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontColor(ThemeColorController.brand())
          .onClick(() => { this.onAction(); })
      }
      Button() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('app.color.hm_text_secondary')])
      }
      .width($r('app.float.preview_control_size'))
      .height($r('app.float.preview_control_size'))
      .padding(0)
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.action_close'))
      .onClick(() => { this.onClose(); })
    }
    .width('100%')
    .padding($r('app.float.space_m'))
    .alignItems(VerticalAlign.Center)
  }
}
