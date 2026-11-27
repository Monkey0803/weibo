/* 显示与光感：常用效果及可展开的高级材质设置。 */
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { appSettings } from '../model/AppSettings';
import { THEME_COLOR_OPTIONS, MATERIAL_TYPE_OPTIONS, MATERIAL_LEVEL_OPTIONS, CARD_GLOW_INTENSITY_OPTIONS,
  CARD_GLOW_PALETTE_OPTIONS } from '../model/SettingsOptions';
import { settingsViewModel } from '../viewmodel/SettingsViewModel';
import { MaterialController } from '../service/MaterialController';
import { ResponsiveContent } from './ResponsiveContent';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';
import { scrollers } from '../service/ScrollerRegistry';
import { AppIcon } from './AppIcon';
import { AppConfirmDialog } from '../common/components/AppConfirmDialog';
import { BackgroundPickOutcome } from '../common/constants/SettingsConstants';
import { ThemeColorController } from '../service/ThemeColorController';
import { SettingsOptionRow } from './SettingsOptionRow';

@ComponentV2
export struct SettingsAppearanceView {
  @Local viewportHeightVp: number = 0;
  @Local contentHeightVp: number = 0;
  @Local advancedExpanded: boolean = false;
  @Local previewDialogId: number | undefined = undefined;
  @Local previewDialogActive: boolean = false;
  @Local previewCloseRequested: boolean = false;

  private hostContext(): common.UIAbilityContext {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    return context as common.UIAbilityContext;
  }

  private async chooseBackgroundImage(): Promise<void> {
    const outcome: BackgroundPickOutcome = await settingsViewModel.pickBackgroundImage(this.hostContext());
    if (outcome === BackgroundPickOutcome.FAILED) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.background_pick_failed') });
      } catch (err) {
        const error: BusinessError = err as BusinessError;
        console.error('showToast (background image) failed: ' + error.code.toString());
      }
    }
  }

  private async openPreviewDialog(): Promise<void> {
    if (this.previewDialogActive) {
      return;
    }
    this.previewDialogActive = true;
    this.previewCloseRequested = false;
    const options: promptAction.CustomDialogOptions = {
      builder: () => { this.PreviewDialogContent(); },
      autoCancel: true,
      systemMaterial: MaterialController.dialogMaterial(appSettings.immersiveOn),
      onDidDisappear: () => {
        this.previewDialogActive = false;
        this.previewDialogId = undefined;
        this.previewCloseRequested = false;
      }
    };
    try {
      const dialogId: number = await this.getUIContext().getPromptAction().openCustomDialog(options);
      if (!this.previewDialogActive) {
        return;
      }
      this.previewDialogId = dialogId;
      if (this.previewCloseRequested) {
        this.closePreviewDialog();
      }
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('openCustomDialog (preview) failed: ' + error.code.toString());
      this.previewDialogActive = false;
      this.previewCloseRequested = false;
    }
  }

  private closePreviewDialog(): void {
    const dialogId: number | undefined = this.previewDialogId;
    if (dialogId === undefined) {
      this.previewCloseRequested = true;
      return;
    }
    this.previewDialogId = undefined;
    try {
      this.getUIContext().getPromptAction().closeCustomDialog(dialogId);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('closeCustomDialog (preview) failed: ' + error.code.toString());
      this.previewDialogId = dialogId;
      this.previewCloseRequested = false;
    }
  }

  @Builder
  PreviewDialogContent() {
    AppConfirmDialog({
      title: $r('app.string.dialog_preview_title'),
      message: $r('app.string.dialog_preview_message'),
      confirmLabel: $r('app.string.dialog_preview_confirm'),
      onCancel: () => { this.closePreviewDialog(); },
      onConfirm: () => { this.closePreviewDialog(); }
    })
  }

  @Builder
  SectionTitle(title: ResourceStr) {
    Text(title)
      .fontSize($r('app.float.font_size_section'))
      .fontColor($r('app.color.hm_text_secondary'))
      .margin({ top: $r('app.float.space_xl'), bottom: $r('app.float.space_s'), left: $r('app.float.space_xs') })
  }

  @Builder
  Leading(icon: Resource, title: ResourceStr, isOn: boolean = true) {
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
  }

  @Builder
  SwitchRow(icon: Resource, title: ResourceStr, isOn: boolean, toggle: (value: boolean) => void) {
    Row() {
      this.Leading(icon, title, isOn)
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(ThemeColorController.brand())
        .onChange((value: boolean) => toggle(value))
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
  }

  @Builder
  BackgroundRow() {
    Row() {
      this.Leading($r('app.media.icon_image'), $r('app.string.row_background_image'))
      Blank()
      Text(appSettings.backgroundImagePath.length > 0 ? $r('app.string.background_configured') :
        $r('app.string.background_not_set'))
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_secondary'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize($r('app.float.icon_size_small'))
        .fontColor([$r('app.color.hm_text_secondary')])
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
    .enabled(!settingsViewModel.backgroundPickerActive)
    .opacity(settingsViewModel.backgroundPickerActive ? 0.5 : 1)
    .onClick(() => { this.chooseBackgroundImage(); })
  }

  @Builder
  ClearBackgroundRow() {
    Row() {
      this.Leading($r('app.media.icon_image'), $r('app.string.row_remove_background'), false)
      Blank()
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
    .onClick(() => settingsViewModel.clearBackgroundImage(this.hostContext()))
  }

  @Builder
  AdvancedContent() {
    Column() {
      SettingsOptionRow({
        icon: $r('app.media.icon_rings'),
        title: $r('app.string.row_material_type'),
        choice: MATERIAL_TYPE_OPTIONS,
        currentId: appSettings.materialType,
        onPick: (id: string) => settingsViewModel.setMaterialType(id)
      })
      Divider().color($r('app.color.hm_divider'))
      SettingsOptionRow({
        icon: $r('app.media.icon_sliders'),
        title: $r('app.string.row_material_level'),
        choice: MATERIAL_LEVEL_OPTIONS,
        currentId: appSettings.materialLevel,
        onPick: (id: string) => settingsViewModel.setMaterialLevel(id)
      })
      Divider().color($r('app.color.hm_divider'))
      Row() {
        this.Leading($r('app.media.icon_sun'), $r('app.string.row_dialog_preview'))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('app.color.hm_text_secondary')])
      }
      .width('100%')
      .height($r('app.float.row_height'))
      .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
      .onClick(() => { this.openPreviewDialog(); })
    }
    .width('100%')
    .backgroundColor($r('app.color.hm_card_background'))
    .borderRadius($r('app.float.radius_card'))

    Text(settingsViewModel.stateCaption)
      .fontSize($r('app.float.font_size_caption'))
      .fontColor($r('app.color.hm_text_secondary'))
      .margin({ top: $r('app.float.space_s'), left: $r('app.float.space_xs') })
    Text(settingsViewModel.levelCaption)
      .fontSize($r('app.float.font_size_caption'))
      .fontColor($r('app.color.hm_text_secondary'))
      .margin({ top: $r('app.float.space_xs'), left: $r('app.float.space_xs') })
  }

  build() {
    ResponsiveContent() {
      Scroll(scrollers.settingsAppearance) {
        Column() {
          Column() {
            Row().height(safeArea.contentTopInsetVp)
            this.SectionTitle($r('app.string.section_personalization'))
            Column() {
              SettingsOptionRow({
                icon: $r('app.media.icon_rings'),
                title: $r('app.string.row_theme_color'),
                choice: THEME_COLOR_OPTIONS,
                currentId: appSettings.themeColor,
                onPick: (id: string) => settingsViewModel.setThemeColor(id)
              })
              Divider().color($r('app.color.hm_divider'))
              this.BackgroundRow()
              if (appSettings.backgroundImagePath.length > 0) {
                Divider().color($r('app.color.hm_divider'))
                this.ClearBackgroundRow()
              }
            }
            .width('100%')
            .backgroundColor($r('app.color.hm_card_background'))
            .borderRadius($r('app.float.radius_card'))

            this.SectionTitle($r('app.string.section_interface'))
            Column() {
              this.SwitchRow($r('app.media.icon_sliders'), $r('app.string.row_title_bar_auto_hide'),
                appSettings.titleBarAutoHide, (value: boolean) => settingsViewModel.setTitleBarAutoHide(value))
              Divider().color($r('app.color.hm_divider'))
              this.SwitchRow($r('app.media.icon_sliders'), $r('app.string.row_tab_bar_auto_hide'),
                appSettings.tabBarAutoHide, (value: boolean) => settingsViewModel.setTabBarAutoHide(value))
            }
            .width('100%')
            .backgroundColor($r('app.color.hm_card_background'))
            .borderRadius($r('app.float.radius_card'))

            this.SectionTitle($r('app.string.section_light_effects'))
            Column() {
              this.SwitchRow($r('app.media.icon_sun'), $r('app.string.row_immersive'),
                appSettings.immersiveOn, (value: boolean) => settingsViewModel.setImmersiveOn(value))
              Divider().color($r('app.color.hm_divider'))
              this.SwitchRow($r('app.media.icon_bolt'), $r('app.string.row_light_effect'),
                appSettings.lightEffectEnabled, (value: boolean) => settingsViewModel.setLightEffectEnabled(value))
            }
            .width('100%')
            .backgroundColor($r('app.color.hm_card_background'))
            .borderRadius($r('app.float.radius_card'))
            if (!settingsViewModel.immersiveSupported) {
              Text($r('app.string.aux_material_unsupported'))
                .fontSize($r('app.float.font_size_caption'))
                .fontColor($r('app.color.hm_text_secondary'))
                .margin({ top: $r('app.float.space_s'), left: $r('app.float.space_xs') })
            }

            this.SectionTitle($r('app.string.section_card_effects'))
            Column() {
              this.SwitchRow($r('app.media.icon_sun'), $r('app.string.row_card_glow'),
                appSettings.cardGlowEnabled, (value: boolean) => settingsViewModel.setCardGlowEnabled(value))
              if (appSettings.cardGlowEnabled) {
                Divider().color($r('app.color.hm_divider'))
                SettingsOptionRow({
                  icon: $r('app.media.icon_sliders'),
                  title: $r('app.string.row_card_glow_intensity'),
                  choice: CARD_GLOW_INTENSITY_OPTIONS,
                  currentId: appSettings.cardGlowIntensity,
                  onPick: (id: string) => settingsViewModel.setCardGlowIntensity(id)
                })
                Divider().color($r('app.color.hm_divider'))
                SettingsOptionRow({
                  icon: $r('app.media.icon_rings'),
                  title: $r('app.string.row_card_glow_palette'),
                  choice: CARD_GLOW_PALETTE_OPTIONS,
                  currentId: appSettings.cardGlowPalette,
                  onPick: (id: string) => settingsViewModel.setCardGlowPalette(id)
                })
              }
            }
            .width('100%')
            .backgroundColor($r('app.color.hm_card_background'))
            .borderRadius($r('app.float.radius_card'))

            Row() {
              Text($r('app.string.section_advanced_material'))
                .fontSize($r('app.float.font_size_section'))
                .fontColor($r('app.color.hm_text_secondary'))
              Blank()
              SymbolGlyph($r('sys.symbol.chevron_down'))
                .fontSize($r('app.float.icon_size_small'))
                .fontColor([$r('app.color.hm_text_secondary')])
                .rotate({ angle: this.advancedExpanded ? 180 : 0 })
            }
            .width('100%')
            .height($r('app.float.row_height'))
            .padding({ left: $r('app.float.space_xs'), right: $r('app.float.space_xs') })
            .onClick(() => this.advancedExpanded = !this.advancedExpanded)
            if (this.advancedExpanded) {
              this.AdvancedContent()
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
