import { UserRouteParam } from '../model/WeiboModels';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';
import { CommonConstants } from '../common/constants/CommonConstants';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { ResponsiveContent } from './ResponsiveContent';
import { ProfileContent } from './ProfileContent';

@ComponentV2
export struct ProfilePageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: UserRouteParam = new UserRouteParam('', '');
  private viewModel: ProfileViewModel = new ProfileViewModel();
  @Local viewportHeightVp: number = 0;
  @Local contentHeightVp: number = 0;

  aboutToAppear(): void {
    this.viewModel.load(this.routeParam.userId);
  }

  build() {
    ResponsiveContent() {
      Scroll(scrollers.profilePage) {
        Column() {
          Column({ space: $r('app.float.space_m') }) {
            Row().height(safeArea.contentTopInsetVp).margin({ bottom: $r('app.float.space_xs') })
            ProfileContent({ viewModel: this.viewModel, navPathStack: this.navPathStack })
          }
          .width('100%')
          .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l'),
            bottom: $r('app.float.space_xl') })
          .onAreaChange((_oldArea: Area, newArea: Area) => this.contentHeightVp = Number(newArea.height))
          Blank().height(CommonConstants.shortContentEndOffset(this.viewportHeightVp, this.contentHeightVp))
        }
        .width('100%')
      }.width('100%').height('100%').scrollBar(BarState.Off)
        .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
    }
  }
}
