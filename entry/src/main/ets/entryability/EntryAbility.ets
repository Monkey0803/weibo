import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { safeArea } from '../service/SafeAreaController';
import { fullscreenSystemBars } from '../service/FullscreenSystemBarController';

const DOMAIN: number = 0x0000;
const TAG: string = 'HdsEntry';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined;

  private updateWindowBackground(): void {
    if (this.mainWindow === undefined) {
      return;
    }
    try {
      const colorValue: number =
        this.context.resourceManager.getColorSync($r('app.color.start_window_background').id);
      const backgroundColor: string = '#' + (colorValue >>> 0).toString(16).padStart(8, '0').toUpperCase();
      this.mainWindow.setWindowBackgroundColor(backgroundColor);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'updateWindowBackground failed: %{public}d', error.code);
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 主题由设置页控制；这里先跟随系统，恢复订阅后由 ThemeController 覆盖。
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setColorMode failed');
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}d', err.code);
        return;
      }
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      this.mainWindow = mainWindow;
      // 全局沉浸：内容延伸至系统栏区域。
      mainWindow.setWindowLayoutFullScreen(true).catch((e: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}d', e.code);
      });
      // 全屏沉浸：读取系统状态栏 / 导航条高度，供页面内容与悬浮页签栏动态避让。
      safeArea.attach(this.context, mainWindow);
      // 窗口底色与页面主题一致，避免启动和页面切换时闪出错误颜色。
      this.updateWindowBackground();
    });
  }

  onConfigurationUpdate(_newConfig: Configuration): void {
    this.updateWindowBackground();
  }

  /** 接续恢复不会调用 onWindowStageCreate，仍须加载首页并初始化窗口。 */
  onWindowStageRestore(windowStage: window.WindowStage): void {
    this.onWindowStageCreate(windowStage);
  }

  onDestroy(): void {
    fullscreenSystemBars.reset();
    safeArea.detach();
    this.mainWindow = undefined;
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }
}
