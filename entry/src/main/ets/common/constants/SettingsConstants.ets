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

/** 微博卡片径向光晕强度。 */
export enum CardGlowIntensity {
  SOFT = 'soft',
  STANDARD = 'standard',
  VIVID = 'vivid'
}

/** 微博卡片径向光晕配色。 */
export enum CardGlowPalette {
  THEME = 'theme',
  COOL = 'cool',
  WARM = 'warm'
}
