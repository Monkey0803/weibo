/*
 * SettingsStore.ets — 设置的落盘与恢复（@ohos.data.preferences）。
 *
 * 只存语义 id / 布尔量，逐键存：读出来先归一（`ChoiceSet.normalize`），脏值退回默认项。
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { appSettings } from '../model/AppSettings';
import {
  THEME_OPTIONS,
  THEME_COLOR_OPTIONS,
  LANGUAGE_OPTIONS,
  MATERIAL_TYPE_OPTIONS,
  MATERIAL_LEVEL_OPTIONS,
  CARD_GLOW_INTENSITY_OPTIONS,
  CARD_GLOW_PALETTE_OPTIONS,
  VIDEO_PLAYBACK_RATE_OPTIONS
} from '../model/SettingsOptions';
import { PreferencesConstants } from '../common/constants/PreferencesConstants';

export class SettingsStore {
  private store: preferences.Preferences | undefined = undefined;

  /** 打开偏好库并把已存的值读进 appSettings。首次运行读不到值就保持默认。 */
  async load(context: common.Context): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PreferencesConstants.STORE_NAME);
      this.store = store;
      const theme: string = store.getSync(PreferencesConstants.KEY_THEME_MODE, appSettings.themeMode) as string;
      const themeColor: string = store.getSync(PreferencesConstants.KEY_THEME_COLOR, appSettings.themeColor) as string;
      const language: string = store.getSync(PreferencesConstants.KEY_LANGUAGE_MODE, appSettings.languageMode) as string;
      const materialType: string = store.getSync(PreferencesConstants.KEY_MATERIAL_TYPE, appSettings.materialType) as string;
      const materialLevel: string = store.getSync(PreferencesConstants.KEY_MATERIAL_LEVEL, appSettings.materialLevel) as string;
      appSettings.themeMode = THEME_OPTIONS.normalize(theme);
      appSettings.themeColor = THEME_COLOR_OPTIONS.normalize(themeColor);
      appSettings.backgroundImagePath = store.getSync(PreferencesConstants.KEY_BACKGROUND_IMAGE_PATH,
        appSettings.backgroundImagePath) as string;
      appSettings.languageMode = LANGUAGE_OPTIONS.normalize(language);
      appSettings.materialType = MATERIAL_TYPE_OPTIONS.normalize(materialType);
      appSettings.materialLevel = MATERIAL_LEVEL_OPTIONS.normalize(materialLevel);
      appSettings.immersiveOn = store.getSync(PreferencesConstants.KEY_IMMERSIVE_ON, appSettings.immersiveOn) as boolean;
      appSettings.lightEffectEnabled = store.getSync(PreferencesConstants.KEY_LIGHT_EFFECT, appSettings.lightEffectEnabled) as boolean;
      appSettings.titleBarAutoHide = store.getSync(PreferencesConstants.KEY_TITLE_BAR_AUTO_HIDE,
        appSettings.titleBarAutoHide) as boolean;
      appSettings.tabBarAutoHide = store.getSync(PreferencesConstants.KEY_TAB_BAR_AUTO_HIDE,
        appSettings.tabBarAutoHide) as boolean;
      appSettings.gripEnabled = store.getSync(PreferencesConstants.KEY_GRIP_ENABLED, appSettings.gripEnabled) as boolean;
      appSettings.antiPeepEnabled = store.getSync(PreferencesConstants.KEY_ANTI_PEEP_ENABLED, appSettings.antiPeepEnabled) as boolean;
      appSettings.cardGlowEnabled = store.getSync(PreferencesConstants.KEY_CARD_GLOW_ENABLED,
        appSettings.cardGlowEnabled) as boolean;
      const cardGlowIntensity: string = store.getSync(PreferencesConstants.KEY_CARD_GLOW_INTENSITY,
        appSettings.cardGlowIntensity) as string;
      const cardGlowPalette: string = store.getSync(PreferencesConstants.KEY_CARD_GLOW_PALETTE,
        appSettings.cardGlowPalette) as string;
      appSettings.cardGlowIntensity = CARD_GLOW_INTENSITY_OPTIONS.normalize(cardGlowIntensity);
      appSettings.cardGlowPalette = CARD_GLOW_PALETTE_OPTIONS.normalize(cardGlowPalette);
      const videoPlaybackRate: string = store.getSync(PreferencesConstants.KEY_VIDEO_PLAYBACK_RATE,
        appSettings.videoPlaybackRate) as string;
      appSettings.videoPlaybackRate = VIDEO_PLAYBACK_RATE_OPTIONS.normalize(videoPlaybackRate);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('SettingsStore.load failed: ' + error.code.toString());
    }
  }

  /** 把当前 appSettings 全量写回。任何一次用户改动后调用。 */
  save(): void {
    const store: preferences.Preferences | undefined = this.store;
    if (store === undefined) {
      return;
    }
    try {
      store.putSync(PreferencesConstants.KEY_THEME_MODE, appSettings.themeMode);
      store.putSync(PreferencesConstants.KEY_THEME_COLOR, appSettings.themeColor);
      store.putSync(PreferencesConstants.KEY_BACKGROUND_IMAGE_PATH, appSettings.backgroundImagePath);
      store.putSync(PreferencesConstants.KEY_LANGUAGE_MODE, appSettings.languageMode);
      store.putSync(PreferencesConstants.KEY_MATERIAL_TYPE, appSettings.materialType);
      store.putSync(PreferencesConstants.KEY_MATERIAL_LEVEL, appSettings.materialLevel);
      store.putSync(PreferencesConstants.KEY_IMMERSIVE_ON, appSettings.immersiveOn);
      store.putSync(PreferencesConstants.KEY_LIGHT_EFFECT, appSettings.lightEffectEnabled);
      store.putSync(PreferencesConstants.KEY_TITLE_BAR_AUTO_HIDE, appSettings.titleBarAutoHide);
      store.putSync(PreferencesConstants.KEY_TAB_BAR_AUTO_HIDE, appSettings.tabBarAutoHide);
      store.putSync(PreferencesConstants.KEY_GRIP_ENABLED, appSettings.gripEnabled);
      store.putSync(PreferencesConstants.KEY_ANTI_PEEP_ENABLED, appSettings.antiPeepEnabled);
      store.putSync(PreferencesConstants.KEY_CARD_GLOW_ENABLED, appSettings.cardGlowEnabled);
      store.putSync(PreferencesConstants.KEY_CARD_GLOW_INTENSITY, appSettings.cardGlowIntensity);
      store.putSync(PreferencesConstants.KEY_CARD_GLOW_PALETTE, appSettings.cardGlowPalette);
      store.putSync(PreferencesConstants.KEY_VIDEO_PLAYBACK_RATE, appSettings.videoPlaybackRate);
      store.flush().catch((err: BusinessError) => {
        console.error('SettingsStore.flush failed: ' + err.code.toString());
      });
    } catch (err) {
      // putSync 可能抛（库已关闭 / 存储异常）：落盘失败不该让设置操作崩掉。
      const error: BusinessError = err as BusinessError;
      console.error('SettingsStore.save failed: ' + error.code.toString());
    }
  }
}

export const settingsStore: SettingsStore = new SettingsStore();
