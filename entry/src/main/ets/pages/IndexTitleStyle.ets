/*
 * IndexTitleStyle.ets — 全 App 共用的标题栏材质、滚动模糊与动态显隐配置。
 *
 * 外壳 HdsNavigation 与所有 HdsNavDestination 都使用同一套：
 * - 标题栏作为浮层（enableComponentSafeArea=false），自身避让系统状态栏（avoidLayoutSafeArea=true）；
 * - 静止态背景透明；滚动后露出沉浸光感材质背板（材质不可用时补系统灰底，保证可读性）；
 * - 默认用 GRADIENT_BLUR（半透明 → 模糊）：IMMERSIVE_GRADIENT_BLUR 在浅色主题下会把标题文字与
 *   状态栏图标切成白色，浅色壁纸上不可读；深色 / 固定深色背景应用可按需替换。
 */

import {
  DynamicHideParams,
  HideMode,
  HdsNavigationTitleBarStyle,
  HdsNavigationTitle,
  HdsNavigationTitleBarOptions,
  ScrollEffectOptions,
  ScrollEffectType,
  SystemMaterialParams,
  TitleBarContentOptions,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { appSettings } from '../model/AppSettings';
import { MaterialController } from '../service/MaterialController';
import { CommonConstants } from '../common/constants/CommonConstants';

export function indexMaterialParams(): SystemMaterialParams {
  return MaterialController.params(appSettings.materialType, appSettings.materialLevel, appSettings.immersiveOn);
}

export function indexDynamicHideParams(): DynamicHideParams {
  const on: boolean = CommonConstants.CONTENT_UNDER_TITLE_BAR && CommonConstants.TITLE_BAR_DYNAMIC_HIDE;
  const params: DynamicHideParams = {
    hideTitleArea: on,
    hideStatusBar: on,
    hideBottomBuilder: false,
    mode: HideMode.SCROLL_UP_TO,
    hideOffset: CommonConstants.TITLE_BAR_HIDE_OFFSET_VP,
    hideRatio: CommonConstants.TITLE_BAR_HIDE_RATIO
  };
  return params;
}

function titleBackdropColor(): ResourceColor {
  return MaterialController.immersiveActive(appSettings.immersiveOn)
    ? Color.Transparent
    : $r('sys.color.comp_background_gray');
}

export function indexMaterialTitleStyle(): TitleBarStyleOptions {
  const backdrop: ResourceColor = titleBackdropColor();
  const original: HdsNavigationTitleBarStyle = {
    backgroundStyle: { backgroundColor: Color.Transparent }
  };
  const scrolled: HdsNavigationTitleBarStyle = {
    backgroundStyle: { backgroundColor: backdrop }
  };
  const scrollEffectOpts: ScrollEffectOptions = {
    enableScrollEffect: CommonConstants.CONTENT_UNDER_TITLE_BAR,
    scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
    blurEffectiveStartOffset: LengthMetrics.vp(CommonConstants.TITLE_BAR_BLUR_START_VP),
    blurEffectiveEndOffset: LengthMetrics.vp(CommonConstants.TITLE_BAR_BLUR_END_VP)
  };
  const style: TitleBarStyleOptions = {
    scrollEffectOpts: scrollEffectOpts,
    originalStyle: original,
    scrollEffectStyle: scrolled,
    systemMaterialEffect: indexMaterialParams()
  };
  return style;
}

export function indexTitleOptions(mainTitle: ResourceStr): HdsNavigationTitleBarOptions {
  const title: HdsNavigationTitle = { mainTitle: mainTitle };
  const content: TitleBarContentOptions = { title: title };
  const options: HdsNavigationTitleBarOptions = {
    avoidLayoutSafeArea: true,
    enableComponentSafeArea: false,
    content: content,
    style: indexMaterialTitleStyle()
  };
  return options;
}
