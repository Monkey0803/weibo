import { FeedKind, LoadState, WeiboPost } from '../model/WeiboModels';
import { RouterConstants } from '../common/constants/RouterConstants';
import { feedViewModel } from '../viewmodel/FeedViewModel';
import { deviceService } from '../service/DeviceService';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { ResponsiveContent } from './ResponsiveContent';
import { WeiboPostCard } from './WeiboPostCard';

@ComponentV2
export struct HomeTabView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param underTitleBar: boolean = true;

  aboutToAppear(): void {
    if (feedViewModel.state === LoadState.IDLE) {
      feedViewModel.refresh();
    }
  }

  private login(): void {
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_LOGIN, ''));
  }

  @Builder
  feedSelector() {
    Row({ space: $r('app.float.space_s') }) {
      Button($r('app.string.feed_following'))
        .buttonStyle(feedViewModel.kind === FeedKind.FOLLOWING ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.TEXTUAL)
        .onClick(() => feedViewModel.select(FeedKind.FOLLOWING))
      Button($r('app.string.feed_hot'))
        .buttonStyle(feedViewModel.kind === FeedKind.HOT ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.TEXTUAL)
        .onClick(() => feedViewModel.select(FeedKind.HOT))
      Blank()
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize($r('app.float.icon_size_small'))
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .onClick(() => feedViewModel.refresh())
    }
    .width('100%')
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
      List({ scroller: scrollers.home }) {
        ListItem() {
          Column({ space: $r('app.float.space_m') }) {
            Row().height(this.underTitleBar ? safeArea.contentTopInsetVp : 0)
            this.feedSelector()
            this.statusContent()
          }.width('100%')
        }
        ForEach(feedViewModel.posts, (post: WeiboPost) => {
          ListItem() { WeiboPostCard({ post: post, navPathStack: this.navPathStack }) }
        }, (post: WeiboPost) => post.id)
        if (feedViewModel.state === LoadState.READY && feedViewModel.hasMore) {
          ListItem() {
            Button(feedViewModel.loadingMore ? $r('app.string.loading_more') : $r('app.string.action_refresh'))
              .buttonStyle(ButtonStyleMode.TEXTUAL)
              .enabled(!feedViewModel.loadingMore)
              .onClick(() => feedViewModel.loadMore())
              .width('100%')
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
