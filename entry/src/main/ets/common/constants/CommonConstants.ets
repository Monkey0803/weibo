/*
 * CommonConstants.ets — 应用级通用逻辑常量。
 *
 * 纯逻辑常量（超时、分页、默认下标等）集中在这里；随环境变化的颜色 / 文本 / 尺寸
 * 一律走 resources（color.json / string.json / float.json）。
 */
export class CommonConstants {
  /** 应用启动时的默认页签下标。 */
  static readonly DEFAULT_TAB_INDEX: number = 0;

  /** 图片预览双指缩放上限。 */
  static readonly IMAGE_PREVIEW_MAX_SCALE: number = 4;
  static readonly IMAGE_PREVIEW_DOUBLE_TAP_SCALE: number = 2.5;

  /** 信息流距末尾剩余条目数达到该阈值时预加载下一页。 */
  static readonly AUTO_LOAD_MORE_THRESHOLD: number = 3;

  /** 信息流滚动超过约一屏后显示返回顶部按钮（vp）。 */
  static readonly BACK_TO_TOP_SHOW_OFFSET_VP: number = 600;

  /** HDS 紧凑标题栏（MINI）高度（vp）——HDS 规范固定值，用于可滚动内容的首屏顶部占位。 */
  static readonly TITLE_BAR_HEIGHT_VP: number = 56;

  /** 短页留出约四分之一屏滚动范围，避免刚收起标题栏就触底并被 HDS 自动显示。 */
  static shortContentScrollDistance(viewportHeight: number): number {
    return Math.max(CommonConstants.TITLE_BAR_SCROLL_DISTANCE_VP, viewportHeight / 4);
  }

  /** 内容不足一屏时，补足实际可滚动距离。 */
  static shortContentEndOffset(viewportHeight: number, contentHeight: number): number {
    return Math.max(0, viewportHeight + CommonConstants.shortContentScrollDistance(viewportHeight) - contentHeight);
  }

  /**
   * 标题栏与内容的关系：
   * - true  —— 内容穿透标题栏（沉浸式动态模糊）：标题栏的 enableComponentSafeArea 为 false，
   *            内容全屏布局、滚动时穿过标题栏下方，由 scrollEffectOpts 触发模糊。
   * - false —— 内容避让标题栏：enableComponentSafeArea 为 true，内容从标题栏下方开始。
   * 两种模式互斥；切换这一项即可（视图的顶部预留由 underTitleBar 参数联动）。
   */
  static readonly CONTENT_UNDER_TITLE_BAR: boolean = true;

  /**
   * 标题栏 / 状态栏的动态显隐（沉浸光感的一环）。
   * - true  —— 上滑到固定位置隐藏、下滑到固定位置显示（HideMode.SCROLL_UP_TO）。
   *            仅在有内容滚动联动的穿透模式下有意义（需配合 bindToScrollable）。
   * - false —— 标题栏 / 状态栏常驻。
   * 与 CONTENT_UNDER_TITLE_BAR 同时为 true 时才会挂上 dynamicHideTitleBar。
   */
  static readonly TITLE_BAR_DYNAMIC_HIDE: boolean = true;

  /** 动态显隐的滚动偏移阈值（vp）：滚动到该位置开始隐藏标题栏。 */
  static readonly TITLE_BAR_HIDE_OFFSET_VP: number = 0;

  /** 标题栏隐藏长度与滚动距离之比，取值 [1.0, 3.0]（每滚动 1vp，标题栏隐藏 1/hideRatio vp）。 */
  static readonly TITLE_BAR_HIDE_RATIO: number = 2.0;

  /** 标题栏按 hideRatio 完整收起所需的最短滚动距离。 */
  static readonly TITLE_BAR_SCROLL_DISTANCE_VP: number =
    CommonConstants.TITLE_BAR_HEIGHT_VP * CommonConstants.TITLE_BAR_HIDE_RATIO;

  /** 动态模糊的生效区间（vp）：滚动偏移在 [start, end] 之间时标题栏逐渐变模糊。 */
  static readonly TITLE_BAR_BLUR_START_VP: number = 0;
  static readonly TITLE_BAR_BLUR_END_VP: number = 20;
}
