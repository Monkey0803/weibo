import { appSettings } from '../model/AppSettings';
import { ThemeColor } from '../common/constants/SettingsConstants';

/** 把持久化的语义色值映射为随深浅模式切换的资源色。 */
export class ThemeColorController {
  static brand(): ResourceColor {
    if (appSettings.themeColor === ThemeColor.BLUE) {
      return $r('app.color.hm_brand_blue');
    }
    if (appSettings.themeColor === ThemeColor.PURPLE) {
      return $r('app.color.hm_brand_purple');
    }
    if (appSettings.themeColor === ThemeColor.PINK) {
      return $r('app.color.hm_brand_pink');
    }
    if (appSettings.themeColor === ThemeColor.ORANGE) {
      return $r('app.color.hm_brand_orange');
    }
    return $r('app.color.hm_brand');
  }

  static soft(): ResourceColor {
    if (appSettings.themeColor === ThemeColor.BLUE) {
      return $r('app.color.hm_brand_blue_soft');
    }
    if (appSettings.themeColor === ThemeColor.PURPLE) {
      return $r('app.color.hm_brand_purple_soft');
    }
    if (appSettings.themeColor === ThemeColor.PINK) {
      return $r('app.color.hm_brand_pink_soft');
    }
    if (appSettings.themeColor === ThemeColor.ORANGE) {
      return $r('app.color.hm_brand_orange_soft');
    }
    return $r('app.color.hm_brand_soft');
  }

  static brandPressed(): ResourceColor {
    if (appSettings.themeColor === ThemeColor.BLUE) {
      return $r('app.color.hm_brand_blue_pressed');
    }
    if (appSettings.themeColor === ThemeColor.PURPLE) {
      return $r('app.color.hm_brand_purple_pressed');
    }
    if (appSettings.themeColor === ThemeColor.PINK) {
      return $r('app.color.hm_brand_pink_pressed');
    }
    if (appSettings.themeColor === ThemeColor.ORANGE) {
      return $r('app.color.hm_brand_orange_pressed');
    }
    return $r('app.color.hm_brand_pressed');
  }

  static glow(): ResourceColor {
    if (appSettings.themeColor === ThemeColor.BLUE) {
      return $r('app.color.hm_brand_blue_glow');
    }
    if (appSettings.themeColor === ThemeColor.PURPLE) {
      return $r('app.color.hm_brand_purple_glow');
    }
    if (appSettings.themeColor === ThemeColor.PINK) {
      return $r('app.color.hm_brand_pink_glow');
    }
    if (appSettings.themeColor === ThemeColor.ORANGE) {
      return $r('app.color.hm_brand_orange_glow');
    }
    return $r('app.color.hm_card_glow_theme');
  }
}
