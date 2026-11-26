import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsTabs,
  HdsTabsController,
  HdsNavigation,
  HdsNavDestination,
  HdsNavigationTitleMode,
  HdsTabsFloatingStyle,
  HdsSideBar,
  HdsSideMenu,
  HdsSideMenuMainItem
} from '@kit.UIDesignKit';
import { appSettings } from '../model/AppSettings';
import { ImagePreviewRouteParam, PostRouteParam, UserRouteParam, VideoRouteParam } from '../model/WeiboModels';
import { settingsViewModel } from '../viewmodel/SettingsViewModel';
import { backgroundViewModel } from '../viewmodel/BackgroundViewModel';
import { authViewModel } from '../viewmodel/AuthViewModel';
import { antiPeep } from '../service/AntiPeep';
import { gripSensor } from '../service/GripSensor';
import { deviceService } from '../service/DeviceService';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';
import { TabIndex } from '../common/constants/NavigationConstants';
import { RouterConstants } from '../common/constants/RouterConstants';
import { indexDynamicHideParams, indexMaterialParams, indexTitleOptions } from './IndexTitleStyle';
import { HomeTabView } from '../views/HomeTabView';
import { SearchTabView } from '../views/SearchTabView';
import { ProfileTabView } from '../views/ProfileTabView';
import { SettingsTabView } from '../views/SettingsTabView';
import { DetailPageView } from '../views/DetailPageView';
import { LoginPageView } from '../views/LoginPageView';
import { ProfilePageView } from '../views/ProfilePageView';
import { VideoPageView } from '../views/VideoPageView';
import { ImagePreviewView } from '../views/ImagePreviewView';
import { PrivacyVeil } from '../views/PrivacyVeil';
import { AppIcon } from '../views/AppIcon';

@Entry
@ComponentV2
struct Index {
  @Local currentTab: number = CommonConstants.DEFAULT_TAB_INDEX;
  @Local navPathStack: NavPathStack = new NavPathStack();
  private tabsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    settingsViewModel.init(context as common.Context);
    backgroundViewModel.init(context as common.Context);
    deviceService.start(this.getUIContext());
    authViewModel.refresh();
  }

  aboutToDisappear(): void {
    antiPeep.stop();
    gripSensor.stop();
    backgroundViewModel.release();
    deviceService.stop();
  }

  private currentTitle(): ResourceStr {
    if (this.currentTab === TabIndex.SEARCH) {
      return $r('app.string.search_title');
    }
    if (this.currentTab === TabIndex.PROFILE) {
      return $r('app.string.profile_title');
    }
    if (this.currentTab === TabIndex.SETTINGS) {
      return $r('app.string.settings_title');
    }
    return $r('app.string.home_title');
  }

  private floatingStyle(): HdsTabsFloatingStyle {
    const style: HdsTabsFloatingStyle = {
      barBottomMargin: safeArea.bottomInsetVp,
      adaptToHandedness: appSettings.gripEnabled,
      systemMaterialEffect: indexMaterialParams(),
      gradientMask: { maskColor: Color.Transparent }
    };
    return style;
  }

  private boundScrollers(): Scroller[] {
    return [scrollers.home, scrollers.search, scrollers.profile, scrollers.settings];
  }

  private railItems(): HdsSideMenuMainItem[] {
    const items: HdsSideMenuMainItem[] = [];
    items.push(this.railItem('home', $r('app.string.tab_home'), $r('sys.symbol.house'), TabIndex.HOME));
    items.push(this.railItem('search', $r('app.string.tab_search'), $r('sys.symbol.magnifyingglass'), TabIndex.SEARCH));
    items.push(this.railItem('profile', $r('app.string.tab_profile'), $r('sys.symbol.person_crop_circle_fill'), TabIndex.PROFILE));
    items.push(this.railItem('settings', $r('app.string.tab_settings'), $r('sys.symbol.gearshape'), TabIndex.SETTINGS));
    return items;
  }

  private railItem(id: string, label: ResourceStr, symbol: Resource, index: number): HdsSideMenuMainItem {
    return new HdsSideMenuMainItem({
      itemId: id,
      label: label,
      symbol: new SymbolGlyphModifier(symbol),
      action: () => this.currentTab = index
    });
  }

  @Builder
  homeContent() {
    HomeTabView({ navPathStack: this.navPathStack, underTitleBar: CommonConstants.CONTENT_UNDER_TITLE_BAR })
  }

  @Builder
  searchContent() {
    SearchTabView({ navPathStack: this.navPathStack, underTitleBar: CommonConstants.CONTENT_UNDER_TITLE_BAR })
  }

  @Builder
  profileContent() {
    ProfileTabView({ navPathStack: this.navPathStack, underTitleBar: CommonConstants.CONTENT_UNDER_TITLE_BAR })
  }

  @Builder
  settingsContent() {
    SettingsTabView({ underTitleBar: CommonConstants.CONTENT_UNDER_TITLE_BAR })
  }

  @Builder
  tabShell() {
    HdsTabs({ controller: this.tabsController, index: this.currentTab }) {
      TabContent() { this.homeContent() }
        .tabBar(this.barBuilder($r('app.media.icon_house'), $r('app.string.tab_home'), this.currentTab === TabIndex.HOME))
      TabContent() { this.searchContent() }
        .tabBar(this.barBuilder($r('app.media.icon_magnifier'), $r('app.string.tab_search'), this.currentTab === TabIndex.SEARCH))
      TabContent() { this.profileContent() }
        .tabBar(this.barBuilder($r('app.media.icon_person'), $r('app.string.tab_profile'),
          this.currentTab === TabIndex.PROFILE))
      TabContent() { this.settingsContent() }
        .tabBar(this.barBuilder($r('app.media.icon_sliders'), $r('app.string.tab_settings'), this.currentTab === TabIndex.SETTINGS))
    }
    .barPosition(BarPosition.End)
    .barOverlap(true)
    .barFloatingStyle(this.floatingStyle())
    .onChange((index: number) => this.currentTab = index)
    .width('100%').height('100%')
    .backgroundColor($r('app.color.hm_page_transparent'))
  }

  @Builder
  sideRail() {
    HdsSideMenu({
      items: this.railItems(),
      selectedIndex: this.currentTab,
      $selectedIndex: (index: number) => this.currentTab = index
    })
  }

  @Builder
  wideContent() {
    Column() {
      if (this.currentTab === TabIndex.SEARCH) {
        this.searchContent()
      } else if (this.currentTab === TabIndex.PROFILE) {
        this.profileContent()
      } else if (this.currentTab === TabIndex.SETTINGS) {
        this.settingsContent()
      } else {
        this.homeContent()
      }
    }.width('100%').height('100%')
  }

  @Builder
  wideShell() {
    HdsSideBar({
      isShowSideBar: true,
      sideBarContainerType: SideBarContainerType.Embed,
      sideBarPosition: SideBarPosition.Start,
      autoHide: false,
      minSideBarWidth: $r('app.float.rail_min_width'),
      maxSideBarWidth: $r('app.float.rail_max_width'),
      sideBarPanelBuilder: this.sideRail,
      contentPanelBuilder: this.wideContent
    }).width('100%').height('100%')
  }

  @Builder
  barBuilder(icon: Resource, label: ResourceStr, active: boolean) {
    Column({ space: $r('app.float.space_xxs') }) {
      AppIcon({
        source: icon,
        iconSize: $r('app.float.tab_icon_size'),
        tint: active ? $r('app.color.hm_brand') : $r('app.color.hm_text_secondary')
      })
      Text(label)
        .fontSize($r('app.float.tab_font_size'))
        .fontColor(active ? $r('app.color.hm_brand') : $r('app.color.hm_text_secondary'))
    }
    .width('100%').height($r('app.float.tab_item_height'))
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  BackgroundLayer() {
    Image(backgroundViewModel.background)
      .width('100%').height('100%')
      .objectFit(ImageFit.Cover)
      .interpolation(ImageInterpolation.High)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  pageMap(name: string, pageInfos: Object) {
    if (name === RouterConstants.PAGE_DETAIL && pageInfos instanceof PostRouteParam) {
      HdsNavDestination() {
        DetailPageView({ navPathStack: this.navPathStack, routeParam: pageInfos })
      }
      .titleBar(indexTitleOptions($r('app.string.detail_title')))
      .dynamicHideTitleBar(indexDynamicHideParams())
      .backgroundColor($r('app.color.hm_page_transparent'))
    } else if (name === RouterConstants.PAGE_LOGIN) {
      HdsNavDestination() {
        LoginPageView({ navPathStack: this.navPathStack })
      }
      .titleBar(indexTitleOptions($r('app.string.login_title')))
      .backgroundColor($r('app.color.hm_page_transparent'))
    } else if (name === RouterConstants.PAGE_PROFILE && pageInfos instanceof UserRouteParam) {
      HdsNavDestination() {
        ProfilePageView({ navPathStack: this.navPathStack, routeParam: pageInfos })
      }
      .titleBar(indexTitleOptions(pageInfos.title))
      .dynamicHideTitleBar(indexDynamicHideParams())
      .backgroundColor($r('app.color.hm_page_transparent'))
    } else if (name === RouterConstants.PAGE_VIDEO && pageInfos instanceof VideoRouteParam) {
      HdsNavDestination() {
        VideoPageView({ routeParam: pageInfos })
      }
      .titleBar(indexTitleOptions($r('app.string.video_title')))
      .backgroundColor($r('app.color.hm_page_transparent'))
    } else if (name === RouterConstants.PAGE_IMAGE_PREVIEW && pageInfos instanceof ImagePreviewRouteParam) {
      HdsNavDestination() {
        ImagePreviewView({ navPathStack: this.navPathStack, routeParam: pageInfos })
      }
      .hideTitleBar(true)
      .backgroundColor($r('app.color.hm_video_background'))
    }
  }

  build() {
    Stack() {
      this.BackgroundLayer()
      HdsNavigation(this.navPathStack) {
        if (deviceService.wide) {
          this.wideShell()
        } else {
          this.tabShell()
        }
      }
      .titleBar(indexTitleOptions(this.currentTitle()))
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .dynamicHideTitleBar(indexDynamicHideParams())
      .mode(NavigationMode.Stack)
      .navDestination(this.pageMap)
      .bindToScrollable(this.boundScrollers())
      .width('100%').height('100%')
      if (antiPeep.peeking) {
        PrivacyVeil()
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
