/* 设置首页：常用选项与二级设置入口。 */
import { common } from '@kit.AbilityKit';
import { appSettings } from '../model/AppSettings';
import { ChoiceSet, THEME_OPTIONS, LANGUAGE_OPTIONS, VIDEO_PLAYBACK_RATE_OPTIONS } from '../model/SettingsOptions';
import { settingsViewModel } from '../viewmodel/SettingsViewModel';
import { MaterialController } from '../service/MaterialController';
import { ResponsiveContent } from './ResponsiveContent';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { AppIcon } from './AppIcon';
import { AppMenu } from '../common/components/AppMenu';
import { choiceMenu } from '../common/components/ChoiceMenu';
import { RouterConstants } from '../common/constants/RouterConstants';
import { CommonConstants } from '../common/constants/CommonConstants';
import { ThemeColorController } from '../service/ThemeColorController';

@ComponentV2
export struct SettingsTabView {
  @Param underTitleBar: boolean = false;
  @Param navPathStack: NavPathStack = new NavPathStack();
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
  Leading(icon: Resource, title: ResourceStr) {
    Row({ space: $r('app.float.space_m') }) {
      AppIcon({ source: icon, iconSize: $r('app.float.icon_size'), tint: ThemeColorController.brand() })
      Text(title)
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_primary'))
    }
  }

  @Builder
  OptionRow(icon: Resource, title: ResourceStr, choice: ChoiceSet, currentId: string, pick: (id: string) => void) {
    Row() {
      this.Leading(icon, title)
      Blank()
      Text(choice.labelOf(currentId))
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_secondary'))
      AppIcon({
        source: $r('app.media.icon_chevron_down'),
        iconSize: $r('app.float.icon_size_small'),
        tint: $r('app.color.hm_text_secondary')
      })
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
    .bindMenu(AppMenu(choiceMenu(choice, currentId, pick)), MaterialController.menuOptions(appSettings.immersiveOn))
  }

  @Builder
  LinkRow(icon: Resource, title: ResourceStr, route: string) {
    Row() {
      this.Leading(icon, title)
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize($r('app.float.icon_size_small'))
        .fontColor([$r('app.color.hm_text_secondary')])
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
    .onClick(() => this.navPathStack.pushPath(new NavPathInfo(route, '')))
  }

  build() {
    ResponsiveContent() {
      Scroll(scrollers.settings) {
        Column() {
          Column() {
            Row().height(this.underTitleBar ? CommonConstants.TITLE_BAR_HEIGHT_VP : 0)
              .margin({ bottom: $r('app.float.space_l') })
            this.SectionTitle($r('app.string.section_common_settings'))
            Column() {
              this.OptionRow($r('app.media.icon_moon'), $r('app.string.row_theme'), THEME_OPTIONS, appSettings.themeMode,
                (id: string) => settingsViewModel.setTheme(this.hostContext(), id))
              Divider().color($r('app.color.hm_divider'))
              this.OptionRow($r('app.media.icon_globe'), $r('app.string.row_language'), LANGUAGE_OPTIONS,
                appSettings.languageMode, (id: string) => settingsViewModel.setLanguage(id))
              Divider().color($r('app.color.hm_divider'))
              this.OptionRow($r('app.media.icon_play'), $r('app.string.row_video_playback_rate'),
                VIDEO_PLAYBACK_RATE_OPTIONS, appSettings.videoPlaybackRate,
                (id: string) => settingsViewModel.setVideoPlaybackRate(id))
            }
            .width('100%')
            .backgroundColor($r('app.color.hm_card_background'))
            .borderRadius($r('app.float.radius_card'))

            this.SectionTitle($r('app.string.section_more_settings'))
            Column() {
              this.LinkRow($r('app.media.icon_sun'), $r('app.string.settings_appearance_title'),
                RouterConstants.PAGE_SETTINGS_APPEARANCE)
              Divider().color($r('app.color.hm_divider'))
              this.LinkRow($r('app.media.icon_eye_closed'), $r('app.string.settings_privacy_title'),
                RouterConstants.PAGE_SETTINGS_PRIVACY)
            }
            .width('100%')
            .backgroundColor($r('app.color.hm_card_background'))
            .borderRadius($r('app.float.radius_card'))
            Blank().height(safeArea.contentBottomInsetVp)
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
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      .clip(false)
      .backgroundColor($r('app.color.hm_page_transparent'))
    }
  }
}
