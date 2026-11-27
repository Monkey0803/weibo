import { common } from '@kit.AbilityKit';
import { SegmentButtonV2Items, SymbolGlyphModifier, promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  HdsTabs,
  HdsTabsController,
  HdsNavigation,
  HdsNavDestination,
  HdsNavigationTitleMode,
  HdsTabsFloatingStyle,
  HdsSideBar,
  HdsSideMenu,
  HdsSideMenuMainItem,
  HdsNavigationTitleBarOptions
} from '@kit.UIDesignKit';
import { appSettings } from '../model/AppSettings';
import { EntitySearchRouteParam, FeedKind, ImagePreviewRouteParam, LoadState, PostRouteParam,
  RepostListRouteParam, SearchKind,
  SocialListKind, SocialListRouteParam, SocialTextEntity, UserRouteParam,
  VideoRouteParam } from '../model/WeiboModels';
import { settingsViewModel } from '../viewmodel/SettingsViewModel';
import { authViewModel } from '../viewmodel/AuthViewModel';
import { antiPeep } from '../service/AntiPeep';
import { gripSensor } from '../service/GripSensor';
import { deviceService } from '../service/DeviceService';
import { scrollers } from '../service/ScrollerRegistry';
import { tabBarScrollController } from '../service/TabBarScrollController';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';
import { TabIndex } from '../common/constants/NavigationConstants';
import { RouterConstants } from '../common/constants/RouterConstants';
import { indexCustomTitleOptions, indexCustomTitleWithBottomOptions, indexDynamicHideParams, indexMaterialParams,
  indexTitleOptions, previewTitleOptions } from './IndexTitleStyle';
import { HomeTabView } from '../views/HomeTabView';
import { SearchTabView } from '../views/SearchTabView';
import { ProfileTabView } from '../views/ProfileTabView';
import { SettingsTabView } from '../views/SettingsTabView';
import { SettingsAppearanceView } from '../views/SettingsAppearanceView';
import { SettingsPrivacyView } from '../views/SettingsPrivacyView';
import { DetailPageView } from '../views/DetailPageView';
import { LoginPageView } from '../views/LoginPageView';
import { ProfilePageView } from '../views/ProfilePageView';
import { VideoPageView } from '../views/VideoPageView';
import { ImagePreviewTitle, ImagePreviewView } from '../views/ImagePreviewView';
import { MediaActionController } from '../service/MediaActionService';
import { PrivacyVeil } from '../views/PrivacyVeil';
import { AppIcon } from '../views/AppIcon';
import { AppSegmentButton } from '../common/components/AppSegmentButton';
import { AppSearch } from '../common/components/AppSearch';
import { feedViewModel } from '../viewmodel/FeedViewModel';
import { searchViewModel } from '../viewmodel/SearchViewModel';
import { profileTabViewModel } from '../viewmodel/ProfileViewModel';
import { ProfileMenuButton } from '../views/ProfileMenuButton';
import { notificationService, NoticeKind, NoticeRequest } from '../service/NotificationService';
import { MaterialController } from '../service/MaterialController';
import { ThemeColorController } from '../service/ThemeColorController';
import { backgroundImageService } from '../service/BackgroundImageService';
import { AppNoticeBar } from '../common/components/AppNoticeBar';
import { HotSearchPageView } from '../views/HotSearchPageView';
import { SocialListPageView } from '../views/SocialListPageView';
import { RepostListPageView } from '../views/RepostListPageView';
import { ComposePageView } from '../views/ComposePageView';
import { EntitySearchPageView } from '../views/EntitySearchPageView';
import { SocialRichText } from '../common/components/SocialRichText';
import { socialEntityActionService } from '../service/SocialEntityActionService';

@Entry
@ComponentV2
struct Index {
  @Local currentTab: number = CommonConstants.DEFAULT_TAB_INDEX;
  @Local navPathStack: NavPathStack = new NavPathStack();
  @Local previewImageIndex: number = 0;
  @Local previewControlsVisible: boolean = true;
  @Local activeNotice: NoticeRequest = new NoticeRequest('', NoticeKind.INFO, 3000);
  private noticeGeneration: number = 0;
  private noticeDialogId: number | undefined = undefined;
  private noticeTimer: number | undefined = undefined;
  private noticeHandled: boolean = false;
  private previewMediaActions: MediaActionController = new MediaActionController();
  private tabsController: HdsTabsController = new HdsTabsController();
  private feedSegments: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.feed_following') },
    { text: $r('app.string.feed_hot') }
  ]);
  private searchSegments: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.search_kind_all') },
    { text: $r('app.string.search_kind_realtime') },
    { text: $r('app.string.search_kind_hot') },
    { text: $r('app.string.search_kind_video') }
  ]);

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    settingsViewModel.init(context as common.Context);
    deviceService.start(this.getUIContext());
    authViewModel.refresh();
    notificationService.setPresenter((request: NoticeRequest): void => {
      this.presentNotice(request);
    }, (): void => { this.dismissNotice(); });
  }

  aboutToDisappear(): void {
    tabBarScrollController.detach();
    antiPeep.stop();
    gripSensor.stop();
    deviceService.stop();
    notificationService.setPresenter(undefined);
    this.dismissNotice();
  }

  private dismissNotice(): void {
    this.noticeGeneration += 1;
    if (this.noticeTimer !== undefined) {
      clearTimeout(this.noticeTimer);
      this.noticeTimer = undefined;
    }
    const dialogId: number | undefined = this.noticeDialogId;
    this.noticeDialogId = undefined;
    if (dialogId !== undefined) {
      try {
        this.getUIContext().getPromptAction().closeCustomDialog(dialogId);
      } catch (err) {
        const error: BusinessError = err as BusinessError;
        console.error('closeCustomDialog (notice) failed: ' + error.code.toString());
      }
    }
  }

  private openEntity(entity: SocialTextEntity): void {
    const hostContext: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    socialEntityActionService.open(entity, this.navPathStack, hostContext, this.getUIContext());
  }

  private async presentNotice(request: NoticeRequest): Promise<void> {
    this.dismissNotice();
    const generation: number = this.noticeGeneration;
    this.noticeHandled = false;
    this.activeNotice = request;
    const options: promptAction.CustomDialogOptions = {
      builder: () => { this.noticeContent(generation); },
      isModal: false,
      autoCancel: false,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -safeArea.contentBottomInsetVp },
      systemMaterial: MaterialController.dialogMaterial(true),
      onDidDisappear: () => {
        if (generation === this.noticeGeneration) {
          this.noticeDialogId = undefined;
          if (this.noticeTimer !== undefined) {
            clearTimeout(this.noticeTimer);
            this.noticeTimer = undefined;
          }
        }
      }
    };
    try {
      const dialogId: number = await this.getUIContext().getPromptAction().openCustomDialog(options);
      if (generation !== this.noticeGeneration) {
        this.getUIContext().getPromptAction().closeCustomDialog(dialogId);
        return;
      }
      this.noticeDialogId = dialogId;
      this.noticeTimer = setTimeout(() => {
        if (generation === this.noticeGeneration) {
          this.dismissNotice();
        }
      }, request.durationMs);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('openCustomDialog (notice) failed: ' + error.code.toString());
      if (generation === this.noticeGeneration) {
        notificationService.showPlain(this.getUIContext(), request);
      }
    }
  }

  private performNoticeAction(generation: number): void {
    if (this.noticeHandled || generation !== this.noticeGeneration) {
      return;
    }
    this.noticeHandled = true;
    const action: (() => void) | undefined = this.activeNotice.onAction;
    this.dismissNotice();
    if (action !== undefined) {
      action();
    }
  }

  @Builder
  noticeContent(generation: number) {
    AppNoticeBar({
      message: this.activeNotice.message,
      kind: this.activeNotice.kind,
      actionText: this.activeNotice.actionText,
      onAction: () => { this.performNoticeAction(generation); },
      onClose: () => {
        if (generation === this.noticeGeneration) {
          this.dismissNotice();
        }
      }
    })
  }

  private rootTitleOptions(): HdsNavigationTitleBarOptions {
    if (this.currentTab === TabIndex.SEARCH) {
      return indexCustomTitleWithBottomOptions(() => { this.searchTitle(); },
        () => { this.searchKindsTitle(); }, $r('app.float.search_title_segment_height'));
    }
    if (this.currentTab === TabIndex.PROFILE) {
      if (authViewModel.loggedIn && profileTabViewModel.state === LoadState.READY &&
        profileTabViewModel.user.name.length > 0) {
        return indexCustomTitleWithBottomOptions(() => { this.profileTitle(); },
          () => { this.profileStatsTitle(); }, $r('app.float.profile_title_stats_height'));
      }
      return indexCustomTitleOptions(() => { this.profileTitle(); });
    }
    if (this.currentTab === TabIndex.SETTINGS) {
      return indexCustomTitleOptions(() => { this.settingsTitle(); });
    }
    return indexCustomTitleOptions(() => { this.homeTitle(); });
  }

  private previewTitleOptions(param: ImagePreviewRouteParam): HdsNavigationTitleBarOptions {
    return previewTitleOptions(() => {
      this.previewTitleContent(param);
    });
  }

  @Builder
  previewTitleContent(param: ImagePreviewRouteParam) {
    ImagePreviewTitle({
      routeParam: param,
      currentIndex: this.previewImageIndex,
      mediaActions: this.previewMediaActions
    })
  }

  private titleBarAutoHide(): boolean {
    return appSettings.titleBarAutoHide && !(this.currentTab === TabIndex.SEARCH && searchViewModel.focused);
  }

  private searchSegmentIndex(): number {
    if (searchViewModel.kind === SearchKind.REALTIME) {
      return 1;
    }
    if (searchViewModel.kind === SearchKind.HOT) {
      return 2;
    }
    if (searchViewModel.kind === SearchKind.VIDEO) {
      return 3;
    }
    return 0;
  }

  private selectSearchSegment(index: number): void {
    if (index === 1) {
      searchViewModel.selectKind(SearchKind.REALTIME);
    } else if (index === 2) {
      searchViewModel.selectKind(SearchKind.HOT);
    } else if (index === 3) {
      searchViewModel.selectKind(SearchKind.VIDEO);
    } else {
      searchViewModel.selectKind(SearchKind.COMPREHENSIVE);
    }
  }

  private pageBackground(): ResourceColor {
    return appSettings.backgroundImagePath.length > 0 ? $r('app.color.hm_page_transparent') :
      $r('app.color.start_window_background');
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
    if (this.currentTab === TabIndex.SEARCH) {
      return [scrollers.search];
    }
    if (this.currentTab === TabIndex.PROFILE) {
      return [scrollers.profile];
    }
    if (this.currentTab === TabIndex.SETTINGS) {
      return [scrollers.settings];
    }
    return [scrollers.home];
  }

  private selectTab(index: number): void {
    if (this.currentTab === index) {
      return;
    }
    this.currentTab = index;
    tabBarScrollController.showOnTabChange();
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
      action: () => this.selectTab(index)
    });
  }

  @Builder
  settingsTitle() {
    Row() {
      Text($r('app.string.settings_title'))
        .fontSize($r('app.float.font_size_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.hm_text_primary'))
    }
    .width('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
  }

  @Builder
  homeTitle() {
    Row({ space: $r('app.float.space_s') }) {
      AppSegmentButton({
        items: this.feedSegments,
        selectedIndex: feedViewModel.kind,
        config: {
          immersive: appSettings.immersiveOn,
          inMaterialScope: true,
          width: $r('app.float.title_segment_width')
        },
        onSelectedIndexChange: (index: number) => {
          feedViewModel.select(index === 0 ? FeedKind.FOLLOWING : FeedKind.HOT);
        }
      })
      Blank()
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.flame')).fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('sys.color.font_primary')])
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .width($r('app.float.title_action_size')).height($r('app.float.title_action_size'))
      .padding(0)
      .backgroundColor(appSettings.immersiveOn ? $r('app.color.hm_action_glass_fill') : Color.Transparent)
      .backdropBlur(appSettings.immersiveOn ? BlurStyle.COMPONENT_THICK : BlurStyle.NONE)
      .systemMaterial(MaterialController.glassInteractiveMaterial(appSettings.immersiveOn, true))
      .accessibilityText($r('app.string.hot_search_title'))
      .onClick(() => this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_HOT_SEARCH, '')))
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('sys.color.font_primary')])
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .width($r('app.float.title_action_size')).height($r('app.float.title_action_size'))
      .padding(0)
      .backgroundColor(appSettings.immersiveOn ? $r('app.color.hm_action_glass_fill') : Color.Transparent)
      .backdropBlur(appSettings.immersiveOn ? BlurStyle.COMPONENT_THICK : BlurStyle.NONE)
      .systemMaterial(MaterialController.glassInteractiveMaterial(appSettings.immersiveOn, true))
      .accessibilityText($r('app.string.compose_title'))
      .onClick(() => {
        if (authViewModel.loggedIn) {
          this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_COMPOSE, ''));
        } else {
          this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
        }
      })
      Button({ type: ButtonType.Circle }) {
        AppIcon({
          source: $r('app.media.icon_refresh'),
          iconSize: $r('app.float.icon_size_small'),
          tint: $r('sys.color.font_primary')
        })
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .width($r('app.float.title_action_size')).height($r('app.float.title_action_size'))
      .padding(0)
      .backgroundColor(appSettings.immersiveOn ? $r('app.color.hm_action_glass_fill') : Color.Transparent)
      .backdropBlur(appSettings.immersiveOn ? BlurStyle.COMPONENT_THICK : BlurStyle.NONE)
      .systemMaterial(MaterialController.glassInteractiveMaterial(appSettings.immersiveOn, true))
      .accessibilityText($r('app.string.action_refresh'))
      .onClick(() => feedViewModel.refresh())
    }
    .width('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_s') })
  }

  @Builder
  searchTitle() {
    Row() {
      AppSearch({
        text: searchViewModel.query,
        placeholder: $r('app.string.search_hint'),
        useImmersiveMaterial: true,
        onChange: (value: string) => {
          searchViewModel.query = value;
        },
        onSubmit: (value: string) => {
          searchViewModel.search(value);
        },
        onSearchFocus: () => {
          searchViewModel.focused = true;
        },
        onSearchBlur: () => {
          searchViewModel.focused = false;
        }
      })
    }
    .width('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
  }

  @Builder
  searchKindsTitle() {
    Row() {
      AppSegmentButton({
        items: this.searchSegments,
        selectedIndex: this.searchSegmentIndex(),
        config: { immersive: appSettings.immersiveOn, inMaterialScope: true },
        onSelectedIndexChange: (index: number) => this.selectSearchSegment(index)
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
  }

  @Builder
  profileTitle() {
    Row({ space: $r('app.float.space_m') }) {
      if (authViewModel.loggedIn && profileTabViewModel.state === LoadState.READY &&
        profileTabViewModel.user.name.length > 0) {
        Image(profileTabViewModel.user.avatarUrl)
          .width($r('app.float.title_avatar_size'))
          .height($r('app.float.title_avatar_size'))
          .borderRadius($r('app.float.title_avatar_size'))
          .objectFit(ImageFit.Cover)
        Column({ space: $r('app.float.space_xxs') }) {
          Text(profileTabViewModel.user.name)
            .fontSize($r('app.float.font_size_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.hm_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (profileTabViewModel.user.description.length > 0) {
            SocialRichText({
              text: profileTabViewModel.user.description,
              entities: profileTabViewModel.user.descriptionEntities,
              fontSize: $r('app.float.font_size_metric'),
              fontColor: $r('app.color.hm_text_secondary'),
              maxLines: 1,
              brandColor: ThemeColorController.brand(),
              pressedColor: ThemeColorController.brandPressed(),
              onEntityTap: (entity: SocialTextEntity) => this.openEntity(entity)
            })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        ProfileMenuButton({ user: profileTabViewModel.user })
      } else {
        Text($r('app.string.profile_title'))
          .fontSize($r('app.float.font_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.hm_text_primary'))
      }
    }
    .width('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
  }

  @Builder
  profileStat(count: number, label: ResourceStr, kind: number) {
    Column({ space: $r('app.float.space_xxs') }) {
      Text(count.toString())
        .fontSize($r('app.float.font_size_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.hm_text_primary'))
      Text(label)
        .fontSize($r('app.float.font_size_metric'))
        .fontColor($r('app.color.hm_text_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (kind === SocialListKind.FOLLOWING || kind === SocialListKind.FOLLOWERS) {
        this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_SOCIAL_LIST,
          new SocialListRouteParam(profileTabViewModel.user.id, kind, label)));
      }
    })
  }

  @Builder
  profileStatsTitle() {
    Row() {
      this.profileStat(profileTabViewModel.user.followingCount, $r('app.string.profile_following_label'),
        SocialListKind.FOLLOWING)
      this.profileStat(profileTabViewModel.user.followersCount, $r('app.string.profile_followers_label'),
        SocialListKind.FOLLOWERS)
      this.profileStat(profileTabViewModel.user.statusesCount, $r('app.string.profile_posts_label'), -1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  homeContent() {
    HomeTabView({ navPathStack: this.navPathStack })
  }

  @Builder
  searchContent() {
    SearchTabView({ navPathStack: this.navPathStack })
  }

  @Builder
  profileContent() {
    ProfileTabView({ navPathStack: this.navPathStack })
  }

  @Builder
  settingsContent() {
    SettingsTabView({ navPathStack: this.navPathStack })
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
    .scrollable(false)
    .animationDuration(0)
    .barOverlap(true)
    .barFloatingStyle(this.floatingStyle())
    .onChange((index: number) => {
      this.selectTab(index);
    })
    .onAppear(() => tabBarScrollController.attach(this.getUIContext(), this.tabsController, appSettings.tabBarAutoHide))
    .onDisAppear(() => tabBarScrollController.detach())
    .width('100%').height('100%')
    .backgroundColor($r('app.color.hm_page_transparent'))
  }

  @Builder
  sideRail() {
    HdsSideMenu({
      items: this.railItems(),
      selectedIndex: this.currentTab,
      $selectedIndex: (index: number) => this.selectTab(index)
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
        tint: active ? ThemeColorController.brand() : $r('app.color.hm_text_secondary')
      })
      Text(label)
        .fontSize($r('app.float.tab_font_size'))
        .fontColor(active ? ThemeColorController.brand() : $r('app.color.hm_text_secondary'))
    }
    .width('100%').height($r('app.float.tab_item_height'))
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  pageMap(name: string, pageInfos: Object) {
    if (name === RouterConstants.PAGE_DETAIL && pageInfos instanceof PostRouteParam) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          DetailPageView({ navPathStack: this.navPathStack, routeParam: pageInfos })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions($r('app.string.detail_title')))
      .dynamicHideTitleBar(indexDynamicHideParams(appSettings.titleBarAutoHide))
      .bindToScrollable([scrollers.detail])
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_LOGIN) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          LoginPageView({ navPathStack: this.navPathStack })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions($r('app.string.login_title')))
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_PROFILE && pageInfos instanceof UserRouteParam) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          ProfilePageView({ navPathStack: this.navPathStack, routeParam: pageInfos })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions(pageInfos.title))
      .dynamicHideTitleBar(indexDynamicHideParams(appSettings.titleBarAutoHide))
      .bindToScrollable([scrollers.profilePage])
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_VIDEO && pageInfos instanceof VideoRouteParam) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          VideoPageView({ routeParam: pageInfos })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions($r('app.string.video_title')))
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_IMAGE_PREVIEW && pageInfos instanceof ImagePreviewRouteParam) {
      HdsNavDestination() {
        ImagePreviewView({
          navPathStack: this.navPathStack,
          routeParam: pageInfos,
          controlsVisible: this.previewControlsVisible,
          mediaActions: this.previewMediaActions,
          onIndexChange: (index: number) => this.previewImageIndex = index,
          onControlsVisibleChange: (visible: boolean) => this.previewControlsVisible = visible
        })
      }
      .titleBar(this.previewTitleOptions(pageInfos))
      .hideBackButton(true)
      .hideTitleBar(!this.previewControlsVisible)
      .backgroundColor($r('app.color.hm_video_background'))
    } else if (name === RouterConstants.PAGE_HOT_SEARCH) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          HotSearchPageView({ navPathStack: this.navPathStack })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions($r('app.string.hot_search_title')))
      .dynamicHideTitleBar(indexDynamicHideParams(appSettings.titleBarAutoHide))
      .bindToScrollable([scrollers.hotSearch])
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_SOCIAL_LIST && pageInfos instanceof SocialListRouteParam) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          SocialListPageView({ navPathStack: this.navPathStack, routeParam: pageInfos })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions(pageInfos.title))
      .dynamicHideTitleBar(indexDynamicHideParams(appSettings.titleBarAutoHide))
      .bindToScrollable([scrollers.socialList])
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_REPOST_LIST && pageInfos instanceof RepostListRouteParam) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          RepostListPageView({ navPathStack: this.navPathStack, routeParam: pageInfos })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions($r('app.string.reposts_title')))
      .dynamicHideTitleBar(indexDynamicHideParams(appSettings.titleBarAutoHide))
      .bindToScrollable([scrollers.repostList])
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_ENTITY_SEARCH && pageInfos instanceof EntitySearchRouteParam) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          EntitySearchPageView({ navPathStack: this.navPathStack, routeParam: pageInfos })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions(pageInfos.title))
      .dynamicHideTitleBar(indexDynamicHideParams(appSettings.titleBarAutoHide))
      .bindToScrollable([scrollers.entitySearch])
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_COMPOSE) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          ComposePageView({ navPathStack: this.navPathStack })
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
        .titleBar(indexTitleOptions($r('app.string.compose_title')))
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_SETTINGS_APPEARANCE) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          SettingsAppearanceView()
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions($r('app.string.settings_appearance_title')))
      .dynamicHideTitleBar(indexDynamicHideParams(appSettings.titleBarAutoHide))
      .bindToScrollable([scrollers.settingsAppearance])
      .backgroundColor($r('app.color.start_window_background'))
    } else if (name === RouterConstants.PAGE_SETTINGS_PRIVACY) {
      HdsNavDestination() {
        Stack() {
          this.BackgroundLayer()
          SettingsPrivacyView()
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      }
      .titleBar(indexTitleOptions($r('app.string.settings_privacy_title')))
      .dynamicHideTitleBar(indexDynamicHideParams(appSettings.titleBarAutoHide))
      .bindToScrollable([scrollers.settingsPrivacy])
      .backgroundColor($r('app.color.start_window_background'))
    }
  }

  @Builder
  BackgroundLayer() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      if (appSettings.backgroundImagePath.length > 0) {
        Image(backgroundImageService.toImageSource(appSettings.backgroundImagePath))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.High)
          .autoResize(true)
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.hm_background_scrim'))
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
      .titleBar(this.rootTitleOptions())
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .dynamicHideTitleBar(indexDynamicHideParams(this.titleBarAutoHide(), this.currentTab !== TabIndex.SEARCH))
      .mode(NavigationMode.Stack)
      .navDestination(this.pageMap)
      .bindToScrollable(this.boundScrollers())
      .width('100%').height('100%')
      .backgroundColor(this.pageBackground())
      if (antiPeep.peeking) {
        PrivacyVeil()
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
