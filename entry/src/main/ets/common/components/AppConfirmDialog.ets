/** 可复用的确认弹窗内容，由调用方通过 PromptAction 放入系统弹窗背板。 */
@ComponentV2
export struct AppConfirmDialog {
  @Param title: ResourceStr = '';
  @Param message: ResourceStr = '';
  @Param cancelLabel: ResourceStr = $r('app.string.action_cancel');
  @Param confirmLabel: ResourceStr = $r('app.string.action_confirm');
  @Event onCancel: () => void = (): void => {};
  @Event onConfirm: () => void = (): void => {};
  @Local actionTaken: boolean = false;

  build() {
    Column({ space: $r('app.float.space_l') }) {
      Text(this.title)
        .fontSize($r('app.float.font_size_title'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.hm_text_primary'))
        .width('100%')
      Text(this.message)
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_secondary'))
        .width('100%')
      Row({ space: $r('app.float.space_m') }) {
        Button(this.cancelLabel)
          .layoutWeight(1)
          .height($r('app.float.button_height'))
          .onClick(() => {
            if (!this.actionTaken) {
              this.actionTaken = true;
              this.onCancel();
            }
          })
        Button(this.confirmLabel)
          .layoutWeight(1)
          .height($r('app.float.button_height'))
          .onClick(() => {
            if (!this.actionTaken) {
              this.actionTaken = true;
              this.onConfirm();
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_xl'))
  }
}
