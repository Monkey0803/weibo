import { LoadState, WeiboPost } from '../model/WeiboModels';
import { RouterConstants } from '../common/constants/RouterConstants';
import { feedViewModel } from '../viewmodel/FeedViewModel';
import { deviceService } from '../service/DeviceService';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { CommonConstants } from '../common/constants/CommonConstants';
import { ResponsiveContent } from './ResponsiveContent';
import { WeiboPostCard } from './WeiboPostCard';
import { AppIcon } from './AppIcon';
import { gripSensor } from '../service/GripSensor';
import { GlassIconButton } from '../common/components/GlassIconButton';

@ComponentV2
export struct HomeTabView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Local showBackToTop: boolean = false;
  @Local viewportHeightVp: number = 0;
  @Local statusHeightVp: number = 0;
  @Local singlePostHeightVp: number = 0;

  aboutToAppear(): void {
    if (feedViewModel.state === LoadState.IDLE) {
      feedViewModel.refresh();
    }
  }

  private login(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
  }

  private handleVisibleRange(endIndex: number): void {
    const lastPostIndex: number = feedViewModel.posts.length;
    if (!feedViewModel.loadMoreFailed && !feedViewModel.loadMoreAuthRequired &&
      lastPostIndex > 0 && endIndex >= lastPostIndex - CommonConstants.AUTO_LOAD_MORE_THRESHOLD) {
      feedViewModel.loadMore();
    }
  }

  private updateBackToTopVisibility(): void {
    const shouldShow: boolean =
      scrollers.home.currentOffset().yOffset >= CommonConstants.BACK_TO_TOP_SHOW_OFFSET_VP;
    if (this.showBackToTop !== shouldShow) {
      this.showBackToTop = shouldShow;
    }
  }

  private scrollToTop(): void {
    scrollers.home.scrollToIndex(0, true, ScrollAlign.START);
  }

  @Builder
  statusContent() {
    if (feedViewModel.state === LoadState.LOADING) {
      Column({ space: $r('app.float.space_m') }) {
        LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size'))
        Text($r('app.string.loading'))
      }.width('100%')
    } else if (feedViewModel.state === LoadState.ERROR) {
      Column({ space: $r('app.float.space_m') }) {
        if (feedViewModel.authRequired) {
          Text($r('app.string.error_login_required')).fontColor($r('app.color.hm_error'))
        } else if (feedViewModel.posts.length > 0) {
          Text($r('app.string.refresh_failed_showing_previous')).fontColor($r('app.color.hm_error'))
        } else if (feedViewModel.errorMessage.length > 0) {
          Text(feedViewModel.errorMessage).fontColor($r('app.color.hm_error'))
        } else {
          Text($r('app.string.error_api_unavailable')).fontColor($r('app.color.hm_error'))
        }
        if (feedViewModel.authRequired) {
          Button($r('app.string.action_login')).onClick(() => this.login())
        }
        Button($r('app.string.action_retry')).buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => feedViewModel.refresh())
      }.width('100%')
    } else if (feedViewModel.state === LoadState.EMPTY) {
      Text($r('app.string.empty_feed'))
        .fontColor($r('app.color.hm_text_secondary'))
        .width('100%')
    }
  }

  build() {
    ResponsiveContent() {
      Stack({ alignContent: gripSensor.bottomAlign }) {
        Refresh({ refreshing: feedViewModel.refreshing, promptText: $r('app.string.pull_to_refresh') }) {
          List({ scroller: scrollers.home }) {
          ListItem() {
            Column({ space: $r('app.float.space_m') }) {
              Row().height(safeArea.contentTopInsetVp).margin({ bottom: $r('app.float.space_xs') })
              this.statusContent()
            }.width('100%')
          }
          .onAreaChange((_oldArea: Area, newArea: Area) => this.statusHeightVp = Number(newArea.height))
          ForEach(feedViewModel.posts, (post: WeiboPost) => {
            ListItem() { WeiboPostCard({ post: post, navPathStack: this.navPathStack }) }
              .margin({ bottom: $r('app.float.space_m') })
              .onAreaChange((_oldArea: Area, newArea: Area) => this.singlePostHeightVp = Number(newArea.height))
          }, (post: WeiboPost) => post.id)
          if (feedViewModel.posts.length === 0) {
            ListItem() { Row().height(CommonConstants.shortContentScrollDistance(this.viewportHeightVp)) }
          }
          if (feedViewModel.loadingMore) {
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
          } else if (feedViewModel.loadMoreFailed || feedViewModel.loadMoreAuthRequired) {
            ListItem() {
              Column({ space: $r('app.float.space_s') }) {
                Text(feedViewModel.loadMoreAuthRequired
                  ? $r('app.string.error_login_required')
                  : (feedViewModel.loadMoreErrorMessage.length > 0
                    ? feedViewModel.loadMoreErrorMessage : $r('app.string.error_api_unavailable')))
                  .fontColor($r('app.color.hm_error'))
                  .textAlign(TextAlign.Center)
                if (feedViewModel.loadMoreAuthRequired) {
                  Button($r('app.string.action_login')).onClick(() => this.login())
                }
                Button($r('app.string.action_retry'))
                  .buttonStyle(ButtonStyleMode.TEXTUAL)
                  .onClick(() => feedViewModel.loadMore())
              }.width('100%').padding($r('app.float.space_m'))
            }
          }
          }
          .width('100%').height('100%')
          .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
          .contentEndOffset(Math.max(deviceService.wide ? 0 : safeArea.contentBottomInsetVp,
            feedViewModel.posts.length <= 1
              ? CommonConstants.shortContentEndOffset(this.viewportHeightVp,
                this.statusHeightVp + (feedViewModel.posts.length === 1 ? this.singlePostHeightVp :
                  CommonConstants.shortContentScrollDistance(this.viewportHeightVp))) : 0))
          .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .onScrollIndex((_startIndex: number, endIndex: number, _centerIndex: number) => {
            this.handleVisibleRange(endIndex);
          })
          .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) => {
            this.updateBackToTopVisibility();
          })
        }
        .width('100%').height('100%')
        .onRefreshing(() => feedViewModel.refresh())

        if (this.showBackToTop) {
          GlassIconButton({
            icon: $r('sys.symbol.chevron_up'),
            label: $r('app.string.action_back_to_top'),
            controlId: 'home_back_to_top',
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
