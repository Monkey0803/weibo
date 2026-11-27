/*
 * GlassIconButton.ets — 玻璃质感的圆形图标按钮。
 *
 * 接口与 TwoFactor 的同名组件保持一致；普通内容区不支持 systemMaterial 的视觉效果，
 * 因此沿用参考组件的半透明填充、背景模糊、描边和阴影降级样式。
 */
import { ThemeColorController } from '../../service/ThemeColorController';

@ComponentV2
export struct GlassIconButton {
  @Param icon: Resource = $r('sys.symbol.checkmark');
  @Param label: Resource = $r('app.string.action_refresh');
  @Param disabled: boolean = false;
  @Param danger: boolean = false;
  @Param controlId: string = '';
  @Event onTap: () => void = () => {
  };

  private glyphColor(): ResourceColor {
    if (this.danger) {
      return $r('app.color.hm_error');
    }
    return ThemeColorController.brand();
  }

  build() {
    Button({
      type: ButtonType.ROUNDED_RECTANGLE,
      buttonStyle: ButtonStyleMode.NORMAL,
      stateEffect: !this.disabled
    }) {
      SymbolGlyph(this.icon)
        .fontSize($r('app.float.action_glass_icon_size'))
        .fontColor([this.glyphColor()])
    }
    .width($r('app.float.action_glass_size'))
    .height($r('app.float.action_glass_size'))
    .padding(0)
    .backgroundColor($r('app.color.hm_action_glass_fill'))
    .backdropBlur(BlurStyle.COMPONENT_THICK)
    .border({
      width: $r('app.float.action_glass_stroke'),
      color: $r('app.color.hm_action_glass_stroke')
    })
    .borderRadius($r('app.float.action_glass_radius'))
    .shadow({
      radius: $r('app.float.action_glass_shadow_radius'),
      color: $r('app.color.hm_action_glass_shadow'),
      offsetX: 0,
      offsetY: $r('app.float.action_glass_shadow_offset')
    })
    .accessibilityText(this.label)
    .enabled(!this.disabled)
    .onClick(() => {
      if (!this.disabled) {
        this.onTap();
      }
    })
    .id(this.controlId)
  }
}
