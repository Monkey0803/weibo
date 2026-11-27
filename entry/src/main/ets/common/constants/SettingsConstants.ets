/*
 * SettingsConstants.ets — 设置项的语义 id（一组相关常量，用 enum 管理）。
 *
 * 这些 id 会写进偏好库，也是设置行的取值判据：读了旧值 / 脏值一律回到默认项。
 * 命名上避开与 hdsMaterial 的 MaterialType / MaterialLevel 同名，故用 Kind / Grade。
 */

/** 主题：跟随系统 / 浅色 / 深色。 */
export enum ThemeMode {
  SYSTEM = 'system',
  LIGHT = 'light',
  DARK = 'dark'
}

/** 应用强调色预设。 */
export enum ThemeColor {
  TEAL = 'teal',
  BLUE = 'blue',
  PURPLE = 'purple',
  PINK = 'pink',
  ORANGE = 'orange'
}

/** 系统图库选择全局背景后的结果。 */
export enum BackgroundPickOutcome {
  CANCELLED = 0,
  APPLIED = 1,
  FAILED = 2
}

/** 语言：跟随系统 / 简体中文 / 英语。 */
export enum AppLanguage {
  SYSTEM = 'system',
  ZH = 'zh',
  EN = 'en'
}

/** 材质类型，映射 hdsMaterial.MaterialType。 */
export enum MaterialKind {
  ADAPTIVE = 'adaptive',
  IMMERSIVE = 'immersive',
  NONE = 'none'
}

/** 沉浸光感材质（四档），映射 hdsMaterial.MaterialLevel。 */
export enum MaterialGrade {
  EXQUISITE = 'exquisite',
  GENTLE = 'gentle',
  SMOOTH = 'smooth',
  ADAPTIVE = 'adaptive'
}

/** 微博卡片单色光感阴影强度。 */
export enum CardGlowIntensity {
  SOFT = 'soft',
  STANDARD = 'standard',
  VIVID = 'vivid'
}

/** 微博卡片单色光感阴影配色。 */
export enum CardGlowPalette {
  THEME = 'theme',
  COOL = 'cool',
  WARM = 'warm'
}

/** 视频默认播放倍速。值直接对应 ArkUI Video.currentProgressRate。 */
export enum VideoPlaybackRate {
  RATE_0_75 = '0.75',
  RATE_1_00 = '1.0',
  RATE_1_25 = '1.25',
  RATE_1_50 = '1.5',
  RATE_2_00 = '2.0'
}
