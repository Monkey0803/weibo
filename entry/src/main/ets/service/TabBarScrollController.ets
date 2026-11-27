/* 将四个页签的滚动容器绑定到 HdsTabs 的系统显隐动效。 */
import { UIContext } from '@kit.ArkUI';
import { HdsAnimationMode, HdsTabsController } from '@kit.UIDesignKit';
import { scrollers } from './ScrollerRegistry';

export class TabBarScrollController {
  private uiContext: UIContext | undefined = undefined;
  private tabsController: HdsTabsController | undefined = undefined;
  private bound: boolean = false;

  attach(uiContext: UIContext, tabsController: HdsTabsController, enabled: boolean): void {
    this.detach();
    this.uiContext = uiContext;
    this.tabsController = tabsController;
    this.sync(enabled);
  }

  sync(enabled: boolean): void {
    const uiContext: UIContext | undefined = this.uiContext;
    const tabsController: HdsTabsController | undefined = this.tabsController;
    if (uiContext === undefined || tabsController === undefined) {
      return;
    }
    if (enabled && !this.bound) {
      uiContext.bindTabsToScrollable(tabsController, scrollers.home);
      uiContext.bindTabsToScrollable(tabsController, scrollers.search);
      uiContext.bindTabsToScrollable(tabsController, scrollers.profile);
      uiContext.bindTabsToScrollable(tabsController, scrollers.settings);
      this.bound = true;
    } else if (!enabled && this.bound) {
      this.unbind(uiContext, tabsController);
      tabsController.applyShowAnimation(HdsAnimationMode.CLICK_ANIMATION);
    }
  }

  showOnTabChange(): void {
    const tabsController: HdsTabsController | undefined = this.tabsController;
    if (tabsController !== undefined) {
      tabsController.applyShowAnimation(HdsAnimationMode.CLICK_ANIMATION);
    }
  }

  detach(): void {
    const uiContext: UIContext | undefined = this.uiContext;
    const tabsController: HdsTabsController | undefined = this.tabsController;
    if (this.bound && uiContext !== undefined && tabsController !== undefined) {
      this.unbind(uiContext, tabsController);
    }
    this.uiContext = undefined;
    this.tabsController = undefined;
  }

  private unbind(uiContext: UIContext, tabsController: HdsTabsController): void {
    uiContext.unbindTabsFromScrollable(tabsController, scrollers.home);
    uiContext.unbindTabsFromScrollable(tabsController, scrollers.search);
    uiContext.unbindTabsFromScrollable(tabsController, scrollers.profile);
    uiContext.unbindTabsFromScrollable(tabsController, scrollers.settings);
    this.bound = false;
  }
}

export const tabBarScrollController: TabBarScrollController = new TabBarScrollController();
