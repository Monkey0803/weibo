import { authViewModel } from '../viewmodel/AuthViewModel';
import { profileTabViewModel } from '../viewmodel/ProfileViewModel';
import { RouterConstants } from '../common/constants/RouterConstants';
import { safeArea } from '../service/SafeAreaController';
import { scrollers } from '../service/ScrollerRegistry';
import { deviceService } from '../service/DeviceService';
import { ResponsiveContent } from './ResponsiveContent';
import { ProfileContent } from './ProfileContent';
import { AppIcon } from './AppIcon';
import { gripSensor } from '../service/GripSensor';
import { CommonConstants } from '../common/constants/CommonConstants';
import { GlassIconButton } from '../common/components/GlassIconButton';
import { LoadState } from '../model/WeiboModels';
import { feedViewModel } from '../viewmodel/FeedViewModel';
import { postInteractionViewModel } from '../viewmodel/PostInteractionViewModel';
import { notificationService } from '../service/NotificationService';
import { ThemeColorController } from '../service/ThemeColorController';

@ComponentV2
export struct ProfileTabView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param underTitleBar: boolean = true;
  @Local showBackToTop: boolean = false;
  @Local viewportHeightVp: number = 0;
  @Local mainHeightVp: number = 0;
  @Local footerHeightVp: number = 0;
  @Local statsHeightVp: number = 0;
  async aboutToAppear(): Promise<void> {
    await authViewModel.refresh();
    if (authViewModel.loggedIn) {
      await profileTabViewModel.load(authViewModel.userId);
    }
  }

  private login(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
  }

  private confirmLogout(): void {
    const params: AlertDialogParamWithButtons = {
      title: $r('app.string.logout_title'),
      message: $r('app.string.logout_message'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.action_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.action_logout'),
        action: () => { this.logout(); }
      }
    };
    this.getUIContext().showAlertDialog(params);
  }

  private async logout(): Promise<void> {
    if (!await authViewModel.logout()) {
      notificationService.showError(this.getUIContext(), $r('app.string.logout_failed'));
      return;
    }
    profileTabViewModel.clear();
    feedViewModel.clearProtected();
    postInteractionViewModel.clear();
    notificationService.showSuccess(this.getUIContext(), $r('app.string.logout_success'));
  }

  private updateBackToTopVisibility(): void {
    const shouldShow: boolean =
      scrollers.profile.currentOffset().yOffset >= CommonConstants.BACK_TO_TOP_SHOW_OFFSET_VP;
    if (this.showBackToTop !== shouldShow) {
      this.showBackToTop = shouldShow;
    }
  }

  private scrollToTop(): void {
    scrollers.profile.scrollToIndex(0, true, ScrollAlign.START);
  }

  build() {
    ResponsiveContent() {
      Stack({ alignContent: gripSensor.bottomAlign }) {
        List({ scroller: scrollers.profile }) {
          ListItem() { Row().height(this.underTitleBar ? CommonConstants.TITLE_BAR_HEIGHT_VP : 0) }
          if (this.underTitleBar && authViewModel.loggedIn && profileTabViewModel.state === LoadState.READY &&
            profileTabViewModel.user.name.length > 0) {
            ListItem() { Row().height($r('app.float.profile_title_stats_height')) }
              .margin({ bottom: $r('app.float.space_l') })
              .onAreaChange((_oldArea: Area, newArea: Area) => this.statsHeightVp = Number(newArea.height))
          } else {
            ListItem() { Row().height($r('app.float.space_l')) }
          }
          if (!authViewModel.loggedIn) {
            ListItem() {
              Column({ space: $r('app.float.space_l') }) {
                AppIcon({
                  source: $r('app.media.icon_person'),
                  iconSize: $r('app.float.hero_icon_size'),
                  tint: ThemeColorController.brand()
                })
                Text(authViewModel.state === LoadState.ERROR
                  ? $r('app.string.login_check_failed') : $r('app.string.profile_login_intro'))
                  .fontColor($r('app.color.hm_text_secondary'))
                  .textAlign(TextAlign.Center)
                if (authViewModel.state === LoadState.ERROR) {
                  Button($r('app.string.action_retry'))
                    .buttonStyle(ButtonStyleMode.TEXTUAL)
                    .onClick(() => authViewModel.refresh())
                }
                Button($r('app.string.action_login')).onClick(() => this.login())
              }.width('100%').padding($r('app.float.space_xl'))
            }
            .onAreaChange((_oldArea: Area, newArea: Area) => this.mainHeightVp = Number(newArea.height))
          } else {
            ListItem() {
              ProfileContent({
                viewModel: profileTabViewModel,
                navPathStack: this.navPathStack,
                showHeader: !(profileTabViewModel.state === LoadState.READY &&
                  profileTabViewModel.user.name.length > 0)
              })
            }
            .onAreaChange((_oldArea: Area, newArea: Area) => this.mainHeightVp = Number(newArea.height))
            ListItem() {
              Button($r('app.string.action_logout'))
                .buttonStyle(ButtonStyleMode.TEXTUAL)
                .fontColor($r('app.color.hm_error'))
                .width('100%')
                .onClick(() => this.confirmLogout())
            }
            .onAreaChange((_oldArea: Area, newArea: Area) => this.footerHeightVp = Number(newArea.height))
          }
        }
        .width('100%').height('100%')
        .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
        .contentEndOffset(Math.max(deviceService.wide ? 0 : safeArea.contentBottomInsetVp,
          CommonConstants.shortContentEndOffset(this.viewportHeightVp,
            (this.underTitleBar ? CommonConstants.TITLE_BAR_HEIGHT_VP : 0) + this.mainHeightVp +
            (authViewModel.loggedIn ? this.footerHeightVp : 0) +
            (this.underTitleBar && authViewModel.loggedIn && profileTabViewModel.state === LoadState.READY &&
              profileTabViewModel.user.name.length > 0 ? this.statsHeightVp : 0))))
        .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
        .scrollBar(BarState.Off)
        .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) => {
          this.updateBackToTopVisibility();
        })

        if (this.showBackToTop) {
          GlassIconButton({
            icon: $r('sys.symbol.chevron_up'),
            label: $r('app.string.action_back_to_top'),
            controlId: 'profile_back_to_top',
            onTap: () => this.scrollToTop()
          })
            .margin({
              left: $r('app.float.space_l'),
              right: $r('app.float.space_l'),
              bottom: deviceService.wide ? $r('app.float.space_l') : safeArea.contentBottomInsetVp
            })
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}
