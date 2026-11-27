/*
 * SafeAreaController.ets — 全屏沉浸布局的避让尺寸（service 层：屏蔽窗口能力）。
 *
 * 应用在 EntryAbility 里调用了 setWindowLayoutFullScreen(true)，布局不做系统栏避让。
 * 顶部由 HDS 标题栏的 enableComponentSafeArea / avoidLayoutSafeArea 处理；
 * 这里提供「内容要为浮层让出多少」：
 *   - contentTopInsetVp：可滚动内容顶部预留量（= 系统状态栏 + HDS 标题栏高度）；
 *   - contentBottomInsetVp：可滚动内容底部预留量（= 悬浮页签栏避让高度 + 系统导航条高度）；
 *   - bottomInsetVp：系统导航条高度，用于悬浮页签栏上抬 / 页面底部内缩。
 *   - video*InsetVp：全屏视频控制层避开系统栏与挖孔的四向安全距离。
 * 旋转 / 分屏 / 折叠时由 avoidAreaChange 刷新，不要在页面里缓存避让值。
 *
 * 订阅只由 EntryAbility 持有（attach / detach），页面只读取 @Trace 字段。
 */

import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CommonConstants } from '../common/constants/CommonConstants';

const DOMAIN: number = 0x0000;
const TAG: string = 'SafeAreaController';

@ObservedV2
export class SafeAreaController {
  /** 顶部系统状态栏高度（vp）。 */
  @Trace topInsetVp: number = 0;
  /** 底部系统导航条高度（vp）。 */
  @Trace bottomInsetVp: number = 0;
  /** 可滚动内容顶部预留量（vp）= 系统状态栏 + HDS 标题栏高度。 */
  @Trace contentTopInsetVp: number = 0;
  /** 可滚动内容底部预留量（vp）= 悬浮页签栏避让高度 + 系统导航条高度。 */
  @Trace contentBottomInsetVp: number = 0;
  /** 全屏视频控制层顶部安全距离（系统栏与挖孔取较大值）。 */
  @Trace videoTopInsetVp: number = 0;
  /** 全屏视频控制层底部安全距离（导航区与挖孔取较大值）。 */
  @Trace videoBottomInsetVp: number = 0;
  /** 全屏视频控制层左侧挖孔安全距离。 */
  @Trace videoLeftInsetVp: number = 0;
  /** 全屏视频控制层右侧挖孔安全距离。 */
  @Trace videoRightInsetVp: number = 0;

  private mainWindow: window.Window | undefined = undefined;
  private tabClearanceVp: number = 0;

  /** 纯计算：可滚动内容顶部预留量。 */
  static contentTop(top: number, titleHeight: number = CommonConstants.TITLE_BAR_HEIGHT_VP): number {
    return top + titleHeight;
  }

  /** 纯计算：可滚动内容底部预留量。 */
  static contentBottom(tabClearance: number, bottom: number): number {
    return tabClearance + bottom;
  }

  /** 纯计算：底部导航避让高度（手势条与三键导航取较大值）。 */
  static navBottom(indicator: number, systemBottom: number): number {
    return Math.max(indicator, systemBottom);
  }

  /** 纯计算：系统栏和挖孔同时存在时取更安全的一侧距离。 */
  static videoInset(systemInset: number, cutoutInset: number): number {
    return Math.max(systemInset, cutoutInset);
  }

  /** 绑定主窗口：读一次尺寸，并监听旋转 / 分屏 / 折叠带来的变化。 */
  attach(context: common.Context, mainWindow: window.Window): void {
    // 窗口重建 / 接续恢复时可能再次 attach：先释放旧监听，避免重复订阅。
    this.detach();
    this.tabClearanceVp = this.readFloat(context, $r('app.float.tab_clearance'));
    this.mainWindow = mainWindow;
    this.refresh();
    try {
      mainWindow.on('avoidAreaChange', () => {
        this.refresh();
      });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'avoidAreaChange listen failed: %{public}d', error.code);
    }
  }

  /** 解绑监听（窗口销毁时调用）。 */
  detach(): void {
    const mainWindow: window.Window | undefined = this.mainWindow;
    if (mainWindow === undefined) {
      return;
    }
    try {
      mainWindow.off('avoidAreaChange');
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'avoidAreaChange off failed: %{public}d', error.code);
    }
    this.mainWindow = undefined;
  }

  /** 界面尺寸不硬编码在 .ets 里：从 resources 的 float 读取。 */
  private readFloat(context: common.Context, res: Resource): number {
    try {
      return context.resourceManager.getNumber(res.id);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'read float failed: %{public}d', error.code);
      return 0;
    }
  }

  private refresh(): void {
    const mainWindow: window.Window | undefined = this.mainWindow;
    if (mainWindow === undefined) {
      return;
    }
    let systemTop: number = 0;
    let systemBottom: number = 0;
    try {
      const systemArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      systemTop = systemArea.visible ? mainWindow.getUIContext().px2vp(systemArea.topRect.height) : 0;
      systemBottom = systemArea.visible ? mainWindow.getUIContext().px2vp(systemArea.bottomRect.height) : 0;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'getWindowAvoidArea(TYPE_SYSTEM) failed: %{public}d', error.code);
      systemTop = 0;
      systemBottom = 0;
    }
    this.topInsetVp = systemTop;
    let indicatorBottom: number = 0;
    try {
      const indicator: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      indicatorBottom = indicator.visible
        ? mainWindow.getUIContext().px2vp(indicator.bottomRect.height)
        : 0;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'getWindowAvoidArea(TYPE_NAVIGATION_INDICATOR) failed: %{public}d', error.code);
      indicatorBottom = 0;
    }
    let cutoutTop: number = 0;
    let cutoutBottom: number = 0;
    let cutoutLeft: number = 0;
    let cutoutRight: number = 0;
    try {
      const cutoutArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      if (cutoutArea.visible) {
        cutoutTop = mainWindow.getUIContext().px2vp(cutoutArea.topRect.height);
        cutoutBottom = mainWindow.getUIContext().px2vp(cutoutArea.bottomRect.height);
        cutoutLeft = mainWindow.getUIContext().px2vp(cutoutArea.leftRect.width);
        cutoutRight = mainWindow.getUIContext().px2vp(cutoutArea.rightRect.width);
      }
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'getWindowAvoidArea(TYPE_CUTOUT) failed: %{public}d', error.code);
    }
    this.bottomInsetVp = SafeAreaController.navBottom(indicatorBottom, systemBottom);
    this.contentTopInsetVp = SafeAreaController.contentTop(this.topInsetVp);
    this.contentBottomInsetVp = SafeAreaController.contentBottom(this.tabClearanceVp, this.bottomInsetVp);
    this.videoTopInsetVp = SafeAreaController.videoInset(systemTop, cutoutTop);
    this.videoBottomInsetVp = SafeAreaController.videoInset(this.bottomInsetVp, cutoutBottom);
    this.videoLeftInsetVp = cutoutLeft;
    this.videoRightInsetVp = cutoutRight;
  }
}

/** 全局唯一实例。 */
export const safeArea: SafeAreaController = new SafeAreaController();
