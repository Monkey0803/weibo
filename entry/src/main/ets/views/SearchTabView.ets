import { LoadState, WeiboPost } from '../model/WeiboModels';
import { searchViewModel } from '../viewmodel/SearchViewModel';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { deviceService } from '../service/DeviceService';
import { CommonConstants } from '../common/constants/CommonConstants';
import { ResponsiveContent } from './ResponsiveContent';
import { WeiboPostCard } from './WeiboPostCard';
import { gripSensor } from '../service/GripSensor';
import { GlassIconButton } from '../common/components/GlassIconButton';

@ComponentV2
export struct SearchTabView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Local showBackToTop: boolean = false;
  @Local viewportHeightVp: number = 0;
  @Local controlsHeightVp: number = 0;
  @Local singlePostHeightVp: number = 0;

  private handleVisibleRange(endIndex: number): void {
    const lastPostIndex: number = searchViewModel.posts.length;
    if (!searchViewModel.loadMoreFailed && lastPostIndex > 0 &&
      endIndex >= lastPostIndex - CommonConstants.AUTO_LOAD_MORE_THRESHOLD) {
      searchViewModel.loadMore();
    }
  }

  private updateBackToTopVisibility(): void {
    const shouldShow: boolean =
      scrollers.search.currentOffset().yOffset >= CommonConstants.BACK_TO_TOP_SHOW_OFFSET_VP;
    if (this.showBackToTop !== shouldShow) {
      this.showBackToTop = shouldShow;
    }
  }

  private scrollToTop(): void {
    scrollers.search.scrollToIndex(0, true, ScrollAlign.START);
  }

  build() {
    ResponsiveContent() {
      Stack({ alignContent: gripSensor.bottomAlign }) {
        List({ scroller: scrollers.search }) {
          ListItem() {
            Column() {
              Row().height(safeArea.contentTopInsetVp)
              Row().height($r('app.float.search_title_segment_height'))
                .margin({ bottom: $r('app.float.space_l') })
              if (searchViewModel.state === LoadState.LOADING) {
                Row({ space: $r('app.float.space_s') }) {
                  LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size'))
                  Text(searchViewModel.showingPreviousResults
                    ? $r('app.string.search_showing_previous') : $r('app.string.loading'))
                    .fontColor($r('app.color.hm_text_secondary'))
                }
              } else if (searchViewModel.state === LoadState.EMPTY) {
                Text($r('app.string.empty_search')).fontColor($r('app.color.hm_text_secondary')).width('100%')
              } else if (searchViewModel.state === LoadState.ERROR) {
                if (searchViewModel.errorMessage.length > 0) {
                  Text(searchViewModel.errorMessage).fontColor($r('app.color.hm_error')).width('100%')
                } else {
                  Text($r('app.string.error_api_unavailable')).fontColor($r('app.color.hm_error')).width('100%')
                }
                if (searchViewModel.showingPreviousResults) {
                  Text($r('app.string.search_previous_results'))
                    .fontColor($r('app.color.hm_text_secondary'))
                    .width('100%')
                }
                Button($r('app.string.action_retry'))
                  .buttonStyle(ButtonStyleMode.TEXTUAL)
                  .onClick(() => searchViewModel.search(searchViewModel.keyword))
              }
            }.width('100%')
          }
          .onAreaChange((_oldArea: Area, newArea: Area) => this.controlsHeightVp = Number(newArea.height))
          ForEach(searchViewModel.posts, (post: WeiboPost) => {
            ListItem() { WeiboPostCard({ post: post, navPathStack: this.navPathStack }) }
              .margin({ bottom: $r('app.float.space_m') })
              .onAreaChange((_oldArea: Area, newArea: Area) => this.singlePostHeightVp = Number(newArea.height))
          }, (post: WeiboPost) => post.id)
          if (searchViewModel.posts.length === 0) {
            ListItem() { Row().height(CommonConstants.shortContentScrollDistance(this.viewportHeightVp)) }
          }
          if (searchViewModel.loadingMore) {
            ListItem() {
              Row({ space: $r('app.float.space_s') }) {
                LoadingProgress()
                  .width($r('app.float.progress_size'))
                  .height($r('app.float.progress_size'))
                Text($r('app.string.loading_more'))
                  .fontColor($r('app.color.hm_text_secondary'))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
          } else if (searchViewModel.loadMoreFailed) {
            ListItem() {
              Column({ space: $r('app.float.space_s') }) {
                Text(searchViewModel.loadMoreErrorMessage.length > 0
                  ? searchViewModel.loadMoreErrorMessage : $r('app.string.error_api_unavailable'))
                  .fontColor($r('app.color.hm_error'))
                  .textAlign(TextAlign.Center)
                Button($r('app.string.action_retry'))
                  .buttonStyle(ButtonStyleMode.TEXTUAL)
                  .onClick(() => searchViewModel.loadMore())
              }.width('100%').padding($r('app.float.space_m'))
            }
          }
        }
        .width('100%').height('100%')
        .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
        .contentEndOffset(Math.max(deviceService.wide ? 0 : safeArea.contentBottomInsetVp,
          searchViewModel.posts.length <= 1
            ? CommonConstants.shortContentEndOffset(this.viewportHeightVp,
              this.controlsHeightVp + (searchViewModel.posts.length === 1 ? this.singlePostHeightVp :
                CommonConstants.shortContentScrollDistance(this.viewportHeightVp))) : 0))
        .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
        .scrollBar(BarState.Off)
        .onScrollIndex((_startIndex: number, endIndex: number, _centerIndex: number) => {
          this.handleVisibleRange(endIndex);
        })
        .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) => {
          this.updateBackToTopVisibility();
        })

        if (this.showBackToTop) {
          GlassIconButton({
            icon: $r('sys.symbol.chevron_up'),
            label: $r('app.string.action_back_to_top'),
            controlId: 'search_back_to_top',
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
