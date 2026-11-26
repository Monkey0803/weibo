/*
 * AppSettings.ets — 应用设置状态（ArkTS 状态管理 V2）。
 *
 * 用 @ObservedV2 + @Trace：状态被任何持有者读取都会建立观察关系，所以这里做成模块级
 * 单例（appSettings），界面直接 import 读写即可，不需要在组件间层层传参。
 */

import {
  THEME_OPTIONS,
  LANGUAGE_OPTIONS,
  MATERIAL_TYPE_OPTIONS,
  MATERIAL_LEVEL_OPTIONS,
  CARD_GLOW_INTENSITY_OPTIONS,
  CARD_GLOW_PALETTE_OPTIONS
} from './SettingsOptions';

@ObservedV2
export class AppSettings {
  /** 主题：'system' | 'light' | 'dark'。 */
  @Trace themeMode: string = THEME_OPTIONS.defaultValue;
  /** 语言：'system' | 'zh' | 'en'。 */
  @Trace languageMode: string = LANGUAGE_OPTIONS.defaultValue;
  /** 沉浸光感总开关。 */
  @Trace immersiveOn: boolean = true;
  /** 光感反馈开关（沉浸式系统材质的 lightEffect 流光跟随）。 */
  @Trace lightEffectEnabled: boolean = true;
  /** 材质类型：'adaptive' | 'immersive' | 'none'。 */
  @Trace materialType: string = MATERIAL_TYPE_OPTIONS.defaultValue;
  /** 沉浸光感材质四档：'exquisite' | 'gentle' | 'smooth' | 'adaptive'。 */
  @Trace materialLevel: string = MATERIAL_LEVEL_OPTIONS.defaultValue;
  /** 智感握姿：悬浮页签是否跟随握持手。 */
  @Trace gripEnabled: boolean = true;
  /** 防窥保护总开关。 */
  @Trace antiPeepEnabled: boolean = false;
  /** 微博卡片径向光晕开关，与系统材质开关相互独立。 */
  @Trace cardGlowEnabled: boolean = true;
  /** 卡片光晕强度：soft | standard | vivid。 */
  @Trace cardGlowIntensity: string = CARD_GLOW_INTENSITY_OPTIONS.defaultValue;
  /** 卡片光晕配色：theme | cool | warm。 */
  @Trace cardGlowPalette: string = CARD_GLOW_PALETTE_OPTIONS.defaultValue;
}

/** 全局唯一设置实例。 */
export const appSettings: AppSettings = new AppSettings();
