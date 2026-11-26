import { authViewModel } from '../viewmodel/AuthViewModel';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';
import { RouterConstants } from '../common/constants/RouterConstants';
import { safeArea } from '../service/SafeAreaController';
import { scrollers } from '../service/ScrollerRegistry';
import { deviceService } from '../service/DeviceService';
import { ResponsiveContent } from './ResponsiveContent';
import { ProfileContent } from './ProfileContent';

@ComponentV2
export struct ProfileTabView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param underTitleBar: boolean = true;
  private profileViewModel: ProfileViewModel = new ProfileViewModel();

  async aboutToAppear(): Promise<void> {
    await authViewModel.refresh();
    if (authViewModel.loggedIn) {
      await this.profileViewModel.load(authViewModel.userId);
    }
  }

  private login(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
  }

  build() {
    ResponsiveContent() {
      List({ scroller: scrollers.profile }) {
        ListItem() { Row().height(this.underTitleBar ? safeArea.contentTopInsetVp : 0) }
        if (!authViewModel.loggedIn) {
          ListItem() {
            Column({ space: $r('app.float.space_l') }) {
              SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
                .fontSize($r('app.float.hero_icon_size'))
                .fontColor([$r('app.color.hm_brand')])
              Text($r('app.string.profile_login_intro'))
                .fontColor($r('app.color.hm_text_secondary'))
                .textAlign(TextAlign.Center)
              Button($r('app.string.action_login')).onClick(() => this.login())
            }.width('100%').padding($r('app.float.space_xl'))
          }
        } else {
          ListItem() {
            ProfileContent({ viewModel: this.profileViewModel, navPathStack: this.navPathStack })
          }
        }
      }
      .width('100%').height('100%')
      .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
      .contentEndOffset(deviceService.wide ? 0 : safeArea.contentBottomInsetVp)
      .scrollBar(BarState.Off)
    }
  }
}
