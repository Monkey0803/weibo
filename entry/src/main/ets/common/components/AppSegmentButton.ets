import {
  CapsuleSegmentButtonV2,
  ColorMetrics,
  LengthMetrics,
  SegmentButtonV2Items
} from '@kit.ArkUI';
import { MaterialController } from '../../service/MaterialController';

export interface AppSegmentButtonConfig {
  immersive?: boolean;
  inMaterialScope?: boolean;
  width?: Length;
}

@ComponentV2
export struct AppSegmentButton {
  @Param items: SegmentButtonV2Items = new SegmentButtonV2Items([]);
  @Param selectedIndex: number = 0;
  @Param config: AppSegmentButtonConfig = {};
  @Event onSelectedIndexChange: (index: number) => void = () => {};

  private materialMode(): boolean {
    return this.config.inMaterialScope === true && this.config.immersive === true &&
      MaterialController.materialUsable();
  }

  private itemFontColor(material: boolean): ColorMetrics {
    return ColorMetrics.resourceColor(material
      ? $r('sys.color.font_secondary') : $r('app.color.hm_text_secondary'));
  }

  private itemSelectedFontColor(material: boolean): ColorMetrics {
    return ColorMetrics.resourceColor(material
      ? $r('sys.color.font_primary') : $r('app.color.hm_text_primary'));
  }

  private itemSelectedBackgroundColor(material: boolean): ColorMetrics {
    return ColorMetrics.resourceColor(material
      ? $r('app.color.hm_action_glass_fill') : $r('app.color.hm_card_background'));
  }

  private buttonBackgroundColor(material: boolean): ColorMetrics | undefined {
    return material ? undefined : ColorMetrics.resourceColor($r('app.color.hm_card_glass'));
  }

  private buttonRadius(): LengthMetrics {
    return LengthMetrics.resource($r('app.float.radius_card'));
  }

  private buttonPadding(): LengthMetrics {
    return LengthMetrics.resource($r('app.float.segment_button_padding'));
  }

  private itemRadius(): LengthMetrics {
    return LengthMetrics.resource($r('app.float.segment_button_item_radius'));
  }

  build() {
    Column() {
      CapsuleSegmentButtonV2({
        items: this.items,
        selectedIndex: this.selectedIndex,
        $selectedIndex: (index: number): void => {
          this.onSelectedIndexChange(index);
        },
        itemFontColor: this.itemFontColor(this.materialMode()),
        itemSelectedFontColor: this.itemSelectedFontColor(this.materialMode()),
        itemSelectedBackgroundColor: this.itemSelectedBackgroundColor(this.materialMode()),
        itemBorderRadius: this.itemRadius(),
        buttonBackgroundColor: this.buttonBackgroundColor(this.materialMode()),
        buttonBackgroundBlurStyle: this.materialMode() ? undefined : BlurStyle.COMPONENT_THICK,
        buttonBorderRadius: this.buttonRadius(),
        buttonPadding: this.buttonPadding(),
        backgroundSystemMaterial: MaterialController.segmentMaterial(this.materialMode())
      })
    }
    .width(this.config.width ?? '100%')
  }
}
