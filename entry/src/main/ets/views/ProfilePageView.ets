import { UserRouteParam } from '../model/WeiboModels';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';
import { safeArea } from '../service/SafeAreaController';
import { ResponsiveContent } from './ResponsiveContent';
import { ProfileContent } from './ProfileContent';

@ComponentV2
export struct ProfilePageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: UserRouteParam = new UserRouteParam('', '');
  private viewModel: ProfileViewModel = new ProfileViewModel();

  aboutToAppear(): void {
    this.viewModel.load(this.routeParam.userId);
  }

  build() {
    ResponsiveContent() {
      Scroll() {
        Column({ space: $r('app.float.space_m') }) {
          Row().height(safeArea.contentTopInsetVp)
          ProfileContent({ viewModel: this.viewModel, navPathStack: this.navPathStack })
        }
        .width('100%')
        .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l'), bottom: $r('app.float.space_xl') })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }
  }
}
