import { LoadState, SocialListRouteParam, UserRouteParam,
  WeiboUser } from '../model/WeiboModels';
import { RouterConstants } from '../common/constants/RouterConstants';
import { SocialListViewModel } from '../viewmodel/SocialListViewModel';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';
import { SocialRichText } from '../common/components/SocialRichText';
import { ThemeColorController } from '../service/ThemeColorController';
import { socialEntityInteractionGuard } from '../service/SocialEntityInteractionGuard';

@ComponentV2
export struct SocialListPageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: SocialListRouteParam = new SocialListRouteParam('', 0, '');
  private viewModel: SocialListViewModel = new SocialListViewModel();
  @Local viewportHeightVp: number = 0;

  aboutToAppear(): void {
    this.viewModel.load(this.routeParam.userId, this.routeParam.kind);
  }

  private openUser(user: WeiboUser): void {
    if (socialEntityInteractionGuard.blocked()) {
      return;
    }
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_PROFILE,
      new UserRouteParam(user.id, user.name)));
  }

  build() {
    List({ scroller: scrollers.socialList }) {
      ListItem() { Row().height(safeArea.contentTopInsetVp) }
        .margin({ bottom: $r('app.float.space_l') })
      if (this.viewModel.state === LoadState.LOADING) {
        ListItem() {
          Row() {
            LoadingProgress()
              .width($r('app.float.progress_size'))
              .height($r('app.float.progress_size'))
          }.width('100%').justifyContent(FlexAlign.Center).padding($r('app.float.space_xl'))
        }
      } else if (this.viewModel.state === LoadState.EMPTY) {
        ListItem() { Text($r('app.string.empty_social_list')).width('100%').textAlign(TextAlign.Center) }
      } else if (this.viewModel.state === LoadState.ERROR) {
        ListItem() {
          Button($r('app.string.action_retry')).buttonStyle(ButtonStyleMode.TEXTUAL)
            .width('100%').onClick(() => this.viewModel.load(this.routeParam.userId, this.routeParam.kind))
        }
      }
      ForEach(this.viewModel.users, (user: WeiboUser) => {
        ListItem() {
          Row({ space: $r('app.float.space_m') }) {
            Image(user.avatarUrl).width($r('app.float.avatar_size')).height($r('app.float.avatar_size'))
              .borderRadius($r('app.float.avatar_size')).objectFit(ImageFit.Cover)
            Column({ space: $r('app.float.space_xs') }) {
              Text(user.name).fontWeight(FontWeight.Medium).fontColor($r('app.color.hm_text_primary'))
              if (user.description.length > 0) {
                SocialRichText({
                  text: user.description,
                  entities: user.descriptionEntities,
                  fontSize: $r('app.float.font_size_caption'),
                  fontColor: $r('app.color.hm_text_secondary'),
                  maxLines: 2,
                  brandColor: ThemeColorController.brand(),
                  navPathStack: this.navPathStack,
                  onPlainTap: () => this.openUser(user)
                })
              }
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').padding($r('app.float.space_m')).onClick(() => this.openUser(user))
        }
      }, (user: WeiboUser) => user.id)
      if (this.viewModel.users.length === 0) {
        ListItem() { Row().height(CommonConstants.shortContentScrollDistance(this.viewportHeightVp)) }
      }
      if (this.viewModel.hasMore) {
        ListItem() { Button($r('app.string.action_load_more')).buttonStyle(ButtonStyleMode.TEXTUAL)
          .width('100%').onClick(() => this.viewModel.loadMore()) }
      }
    }.width('100%').height('100%').padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
      .contentEndOffset(this.viewModel.users.length <= 1 ? this.viewportHeightVp : 0)
      .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
      .scrollBar(BarState.Off)
  }
}
