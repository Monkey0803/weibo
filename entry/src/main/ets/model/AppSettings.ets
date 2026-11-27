/*
 * AppSettings.ets — 应用设置状态（ArkTS 状态管理 V2）。
 *
 * 用 @ObservedV2 + @Trace：状态被任何持有者读取都会建立观察关系，所以这里做成模块级
 * 单例（appSettings），界面直接 import 读写即可，不需要在组件间层层传参。
 */

import {
  THEME_OPTIONS,
  THEME_COLOR_OPTIONS,
  LANGUAGE_OPTIONS,
  MATERIAL_TYPE_OPTIONS,
  MATERIAL_LEVEL_OPTIONS,
  CARD_GLOW_INTENSITY_OPTIONS,
  CARD_GLOW_PALETTE_OPTIONS,
  VIDEO_PLAYBACK_RATE_OPTIONS
} from './SettingsOptions';

@ObservedV2
export class AppSettings {
  /** 主题：'system' | 'light' | 'dark'。 */
  @Trace themeMode: string = THEME_OPTIONS.defaultValue;
  /** 应用强调色预设。 */
  @Trace themeColor: string = THEME_COLOR_OPTIONS.defaultValue;
  /** 全局背景图片在应用沙箱中的稳定路径；空串表示使用纯色背景。 */
  @Trace backgroundImagePath: string = '';
  /** 语言：'system' | 'zh' | 'en'。 */
  @Trace languageMode: string = LANGUAGE_OPTIONS.defaultValue;
  /** 沉浸光感总开关。 */
  @Trace immersiveOn: boolean = true;
  /** 光感反馈开关（沉浸式系统材质的 lightEffect 流光跟随）。 */
  @Trace lightEffectEnabled: boolean = true;
  /** 主页面标题栏是否跟随内容滚动自动隐藏。 */
  @Trace titleBarAutoHide: boolean = true;
  /** 页签内容上滑时隐藏底部导航栏，下滑时重新显示。 */
  @Trace tabBarAutoHide: boolean = false;
  /** 材质类型：'adaptive' | 'immersive' | 'none'。 */
  @Trace materialType: string = MATERIAL_TYPE_OPTIONS.defaultValue;
  /** 沉浸光感材质四档：'exquisite' | 'gentle' | 'smooth' | 'adaptive'。 */
  @Trace materialLevel: string = MATERIAL_LEVEL_OPTIONS.defaultValue;
  /** 智感握姿：悬浮页签是否跟随握持手。 */
  @Trace gripEnabled: boolean = true;
  /** 防窥保护总开关。 */
  @Trace antiPeepEnabled: boolean = false;
  /** 微博卡片半透明光感开关，与系统材质开关相互独立。 */
  @Trace cardGlowEnabled: boolean = true;
  /** 卡片单色阴影强度：soft | standard | vivid。 */
  @Trace cardGlowIntensity: string = CARD_GLOW_INTENSITY_OPTIONS.defaultValue;
  /** 卡片单色阴影配色：theme | cool | warm。 */
  @Trace cardGlowPalette: string = CARD_GLOW_PALETTE_OPTIONS.defaultValue;
  /** 视频默认播放倍速；单个视频可在更多菜单中临时覆盖。 */
  @Trace videoPlaybackRate: string = VIDEO_PLAYBACK_RATE_OPTIONS.defaultValue;
}

/** 全局唯一设置实例。 */
export const appSettings: AppSettings = new AppSettings();
