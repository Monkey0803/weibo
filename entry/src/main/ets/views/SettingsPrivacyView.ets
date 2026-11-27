/* 交互与隐私：设备能力相关的开关与就近提示。 */
import { common } from '@kit.AbilityKit';
import { appSettings } from '../model/AppSettings';
import { settingsViewModel } from '../viewmodel/SettingsViewModel';
import { antiPeep } from '../service/AntiPeep';
import { gripSensor } from '../service/GripSensor';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';
import { scrollers } from '../service/ScrollerRegistry';
import { ResponsiveContent } from './ResponsiveContent';
import { AppIcon } from './AppIcon';
import { ThemeColorController } from '../service/ThemeColorController';

@ComponentV2
export struct SettingsPrivacyView {
  @Local viewportHeightVp: number = 0;
  @Local contentHeightVp: number = 0;
  private hostContext(): common.UIAbilityContext {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    return context as common.UIAbilityContext;
  }

  @Builder
  SectionTitle(title: ResourceStr) {
    Text(title)
      .fontSize($r('app.float.font_size_section'))
      .fontColor($r('app.color.hm_text_secondary'))
      .margin({ top: $r('app.float.space_xl'), bottom: $r('app.float.space_s'), left: $r('app.float.space_xs') })
  }

  @Builder
  SwitchRow(icon: Resource, title: ResourceStr, isOn: boolean, toggle: (value: boolean) => void) {
    Row() {
      Row({ space: $r('app.float.space_m') }) {
        AppIcon({
          source: icon,
          iconSize: $r('app.float.icon_size'),
          tint: isOn ? ThemeColorController.brand() : $r('app.color.hm_text_secondary')
        })
        Text(title)
          .fontSize($r('app.float.font_size_body'))
          .fontColor($r('app.color.hm_text_primary'))
      }
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(ThemeColorController.brand())
        .onChange((value: boolean) => toggle(value))
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
  }

  build() {
    ResponsiveContent() {
      Scroll(scrollers.settingsPrivacy) {
        Column() {
          Column() {
            Row().height(safeArea.contentTopInsetVp)
            this.SectionTitle($r('app.string.section_interaction'))
            Column() {
              this.SwitchRow($r('app.media.icon_grip'), $r('app.string.row_grip'), appSettings.gripEnabled,
                (value: boolean) => settingsViewModel.setGripEnabled(value))
            }
            .width('100%')
            .backgroundColor($r('app.color.hm_card_background'))
            .borderRadius($r('app.float.radius_card'))
            if (!gripSensor.supported) {
              Text($r('app.string.aux_grip_unsupported'))
                .fontSize($r('app.float.font_size_caption'))
                .fontColor($r('app.color.hm_text_secondary'))
                .margin({ top: $r('app.float.space_s'), left: $r('app.float.space_xs') })
            }

            this.SectionTitle($r('app.string.section_privacy'))
            Column() {
              this.SwitchRow($r('app.media.icon_eye_closed'), $r('app.string.row_antipeep'),
                appSettings.antiPeepEnabled,
                (value: boolean) => settingsViewModel.setAntiPeepEnabled(value, this.hostContext()))
            }
            .width('100%')
            .backgroundColor($r('app.color.hm_card_background'))
            .borderRadius($r('app.float.radius_card'))
            if (!antiPeep.supported) {
              Text($r('app.string.aux_antipeep_unsupported'))
                .fontSize($r('app.float.font_size_caption'))
                .fontColor($r('app.color.hm_text_secondary'))
                .margin({ top: $r('app.float.space_s'), left: $r('app.float.space_xs') })
            }
            Blank().height($r('app.float.space_l'))
            Blank().height(safeArea.bottomInsetVp)
          }
          .width('100%')
          .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
          .alignItems(HorizontalAlign.Start)
          .onAreaChange((_oldArea: Area, newArea: Area) => this.contentHeightVp = Number(newArea.height))
          Blank().height(CommonConstants.shortContentEndOffset(this.viewportHeightVp, this.contentHeightVp))
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
      .scrollBar(BarState.Off)
      .clip(false)
      .backgroundColor($r('app.color.hm_page_transparent'))
    }
  }
}
