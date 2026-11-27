/*
 * PreferencesConstants.ets — 偏好库（@ohos.data.preferences）的库名与 key。
 *
 * key 是纯逻辑字符串，集中在这里，避免在读写两端各写一遍。
 */
export class PreferencesConstants {
  static readonly STORE_NAME: string = 'hds_app_settings_v1';
  static readonly KEY_THEME_MODE: string = 'themeMode';
  static readonly KEY_THEME_COLOR: string = 'themeColor';
  static readonly KEY_BACKGROUND_IMAGE_PATH: string = 'backgroundImagePath';
  static readonly KEY_LANGUAGE_MODE: string = 'languageMode';
  static readonly KEY_MATERIAL_TYPE: string = 'materialType';
  static readonly KEY_MATERIAL_LEVEL: string = 'materialLevel';
  static readonly KEY_IMMERSIVE_ON: string = 'immersiveOn';
  static readonly KEY_LIGHT_EFFECT: string = 'lightEffectEnabled';
  static readonly KEY_TITLE_BAR_AUTO_HIDE: string = 'titleBarAutoHide';
  static readonly KEY_TAB_BAR_AUTO_HIDE: string = 'tabBarAutoHide';
  static readonly KEY_GRIP_ENABLED: string = 'gripEnabled';
  static readonly KEY_ANTI_PEEP_ENABLED: string = 'antiPeepEnabled';
  static readonly KEY_CARD_GLOW_ENABLED: string = 'cardGlowEnabled';
  static readonly KEY_CARD_GLOW_INTENSITY: string = 'cardGlowIntensity';
  static readonly KEY_CARD_GLOW_PALETTE: string = 'cardGlowPalette';
  static readonly KEY_VIDEO_PLAYBACK_RATE: string = 'videoPlaybackRate';
}
