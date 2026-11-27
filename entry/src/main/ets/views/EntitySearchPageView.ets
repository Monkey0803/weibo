import { EntitySearchRouteParam, LoadState, WeiboPost } from '../model/WeiboModels';
import { SearchViewModel } from '../viewmodel/SearchViewModel';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';
import { WeiboPostCard } from './WeiboPostCard';

@ComponentV2
export struct EntitySearchPageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param routeParam: EntitySearchRouteParam = new EntitySearchRouteParam('', '');
  private viewModel: SearchViewModel = new SearchViewModel();
  @Local viewportHeightVp: number = 0;
  @Local singlePostHeightVp: number = 0;

  aboutToAppear(): void {
    this.viewModel.query = this.routeParam.query;
    this.viewModel.search(this.routeParam.query);
  }

  private handleVisibleRange(endIndex: number): void {
    if (!this.viewModel.loadMoreFailed && this.viewModel.posts.length > 0 &&
      endIndex >= this.viewModel.posts.length - CommonConstants.AUTO_LOAD_MORE_THRESHOLD) {
      this.viewModel.loadMore();
    }
  }

  build() {
    List({ scroller: scrollers.entitySearch }) {
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
        ListItem() {
          Text($r('app.string.empty_search')).width('100%').textAlign(TextAlign.Center)
            .fontColor($r('app.color.hm_text_secondary'))
        }
      } else if (this.viewModel.state === LoadState.ERROR) {
        ListItem() {
          Column({ space: $r('app.float.space_s') }) {
            Text(this.viewModel.errorMessage.length > 0 ?
              this.viewModel.errorMessage : $r('app.string.error_api_unavailable'))
              .fontColor($r('app.color.hm_error'))
              .textAlign(TextAlign.Center)
            Button($r('app.string.action_retry'))
              .buttonStyle(ButtonStyleMode.TEXTUAL)
              .onClick(() => this.viewModel.search(this.routeParam.query))
          }.width('100%')
        }
      }
      ForEach(this.viewModel.posts, (post: WeiboPost) => {
        ListItem() { WeiboPostCard({ post: post, navPathStack: this.navPathStack }) }
          .margin({ bottom: $r('app.float.space_m') })
          .onAreaChange((_oldArea: Area, newArea: Area) => this.singlePostHeightVp = Number(newArea.height))
      }, (post: WeiboPost) => post.id)
      if (this.viewModel.posts.length === 0) {
        ListItem() { Row().height(CommonConstants.shortContentScrollDistance(this.viewportHeightVp)) }
      }
      if (this.viewModel.loadingMore) {
        ListItem() {
          Row() {
            LoadingProgress()
              .width($r('app.float.progress_size'))
              .height($r('app.float.progress_size'))
          }.width('100%').justifyContent(FlexAlign.Center).padding($r('app.float.space_l'))
        }
      } else if (this.viewModel.loadMoreFailed) {
        ListItem() { Button($r('app.string.action_retry')).buttonStyle(ButtonStyleMode.TEXTUAL)
          .width('100%').onClick(() => this.viewModel.loadMore()) }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
    .contentEndOffset(this.viewModel.posts.length <= 1
      ? CommonConstants.shortContentEndOffset(this.viewportHeightVp,
        safeArea.contentTopInsetVp + (this.viewModel.posts.length === 1
          ? this.singlePostHeightVp : CommonConstants.shortContentScrollDistance(this.viewportHeightVp))) : 0)
    .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
    .onScrollIndex((_startIndex: number, endIndex: number, _centerIndex: number) =>
      this.handleVisibleRange(endIndex))
    .scrollBar(BarState.Off)
  }
}
