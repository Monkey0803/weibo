import { LoadState, RepostListRouteParam, WeiboPost } from '../model/WeiboModels';
import { RepostListViewModel } from '../viewmodel/RepostListViewModel';
import { scrollers } from '../service/ScrollerRegistry';
import { CommonConstants } from '../common/constants/CommonConstants';
import { WeiboPostCard } from './WeiboPostCard';

@ComponentV2
export struct RepostListPageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: RepostListRouteParam = new RepostListRouteParam('');
  private viewModel: RepostListViewModel = new RepostListViewModel();
  @Local viewportHeightVp: number = 0;
  @Local singlePostHeightVp: number = 0;

  aboutToAppear(): void {
    this.viewModel.load(this.routeParam.postId);
  }

  build() {
    List({ scroller: scrollers.repostList }) {
      ListItem() { Row().height(CommonConstants.TITLE_BAR_HEIGHT_VP) }
        .margin({ bottom: $r('app.float.space_l') })
      if (this.viewModel.state === LoadState.LOADING) {
        ListItem() { LoadingProgress().width('100%').margin($r('app.float.space_xl')) }
      } else if (this.viewModel.state === LoadState.EMPTY) {
        ListItem() { Text($r('app.string.empty_reposts')).width('100%').textAlign(TextAlign.Center) }
      } else if (this.viewModel.state === LoadState.ERROR) {
        ListItem() { Button($r('app.string.action_retry')).buttonStyle(ButtonStyleMode.TEXTUAL)
          .width('100%').onClick(() => this.viewModel.load(this.routeParam.postId)) }
      }
      ForEach(this.viewModel.posts, (post: WeiboPost) => {
        ListItem() { WeiboPostCard({ post: post, navPathStack: this.navPathStack }) }
          .margin({ bottom: $r('app.float.space_m') })
          .onAreaChange((_oldArea: Area, newArea: Area) => this.singlePostHeightVp = Number(newArea.height))
      }, (post: WeiboPost) => post.id)
      if (this.viewModel.posts.length === 0) {
        ListItem() { Row().height(CommonConstants.shortContentScrollDistance(this.viewportHeightVp)) }
      }
      if (this.viewModel.hasMore) {
        ListItem() { Button($r('app.string.action_load_more')).buttonStyle(ButtonStyleMode.TEXTUAL)
          .width('100%').onClick(() => this.viewModel.loadMore()) }
      }
    }.width('100%').height('100%').padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
      .contentEndOffset(this.viewModel.posts.length <= 1
        ? CommonConstants.shortContentEndOffset(this.viewportHeightVp,
          CommonConstants.TITLE_BAR_HEIGHT_VP + (this.viewModel.posts.length === 1
            ? this.singlePostHeightVp : CommonConstants.shortContentScrollDistance(this.viewportHeightVp))) : 0)
      .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
      .scrollBar(BarState.Off)
  }
}
