import { LoadState, WeiboPost } from '../model/WeiboModels';
import { searchViewModel } from '../viewmodel/SearchViewModel';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';
import { deviceService } from '../service/DeviceService';
import { ResponsiveContent } from './ResponsiveContent';
import { WeiboPostCard } from './WeiboPostCard';
import { AppIcon } from './AppIcon';

@ComponentV2
export struct SearchTabView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param underTitleBar: boolean = true;
  @Local query: string = '';

  private submit(): void {
    searchViewModel.search(this.query);
  }

  build() {
    ResponsiveContent() {
      List({ scroller: scrollers.search }) {
        ListItem() {
          Column({ space: $r('app.float.space_m') }) {
            Row().height(this.underTitleBar ? safeArea.contentTopInsetVp : 0)
            Row({ space: $r('app.float.space_s') }) {
              TextInput({ text: this.query, placeholder: $r('app.string.search_hint') })
                .enterKeyType(EnterKeyType.Search)
                .onChange((value: string) => this.query = value)
                .onSubmit(() => this.submit())
                .layoutWeight(1)
                .height($r('app.float.input_height'))
              Button() {
                AppIcon({ source: $r('app.media.icon_magnifier'), iconSize: $r('app.float.icon_size') })
              }
              .accessibilityText($r('app.string.search_title'))
              .onClick(() => this.submit())
            }.width('100%')
            if (searchViewModel.state === LoadState.IDLE) {
              Text($r('app.string.search_intro')).fontColor($r('app.color.hm_text_secondary')).width('100%')
            } else if (searchViewModel.state === LoadState.LOADING) {
              LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size'))
            } else if (searchViewModel.state === LoadState.EMPTY) {
              Text($r('app.string.empty_search')).fontColor($r('app.color.hm_text_secondary')).width('100%')
            } else if (searchViewModel.state === LoadState.ERROR) {
              if (searchViewModel.errorMessage.length > 0) {
                Text(searchViewModel.errorMessage).fontColor($r('app.color.hm_error')).width('100%')
              } else {
                Text($r('app.string.error_api_unavailable')).fontColor($r('app.color.hm_error')).width('100%')
              }
            }
          }.width('100%')
        }
        ForEach(searchViewModel.posts, (post: WeiboPost) => {
          ListItem() { WeiboPostCard({ post: post, navPathStack: this.navPathStack }) }
            .margin({ bottom: $r('app.float.space_m') })
        }, (post: WeiboPost) => post.id)
        if (searchViewModel.hasMore) {
          ListItem() {
            Button(searchViewModel.loadingMore ? $r('app.string.loading_more') : $r('app.string.action_refresh'))
              .buttonStyle(ButtonStyleMode.TEXTUAL)
              .enabled(!searchViewModel.loadingMore)
              .onClick(() => searchViewModel.loadMore())
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
