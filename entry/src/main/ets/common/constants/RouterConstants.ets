/*
 * RouterConstants.ets — 路由名常量，消除魔法字符串。
 *
 * 单模块内用 NavPathStack + @Builder 映射即可；跨模块跳转时应改用系统路由表
 * （module.json5 的 routerMap + resources/base/profile/route_map.json）。
 */
export class RouterConstants {
  static readonly PAGE_DETAIL: string = 'detail';
  static readonly PAGE_LOGIN: string = 'login';
  static readonly PAGE_PROFILE: string = 'profile';
  static readonly PAGE_VIDEO: string = 'video';
  static readonly PAGE_IMAGE_PREVIEW: string = 'imagePreview';
  static readonly PAGE_HOT_SEARCH: string = 'hotSearch';
  static readonly PAGE_SOCIAL_LIST: string = 'socialList';
  static readonly PAGE_REPOST_LIST: string = 'repostList';
  static readonly PAGE_ENTITY_SEARCH: string = 'entitySearch';
  static readonly PAGE_COMPOSE: string = 'compose';
  static readonly PAGE_SETTINGS_APPEARANCE: string = 'settingsAppearance';
  static readonly PAGE_SETTINGS_PRIVACY: string = 'settingsPrivacy';
}
