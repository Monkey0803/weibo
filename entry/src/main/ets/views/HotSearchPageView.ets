import { LoadState, WeiboHotTopic } from '../model/WeiboModels';
import { HotSearchViewModel } from '../viewmodel/HotSearchViewModel';
import { scrollers } from '../service/ScrollerRegistry';
import { CommonConstants } from '../common/constants/CommonConstants';
import { ThemeColorController } from '../service/ThemeColorController';

@ComponentV2
export struct HotSearchPageView {
  private viewModel: HotSearchViewModel = new HotSearchViewModel();
  @Local viewportHeightVp: number = 0;

  aboutToAppear(): void {
    this.viewModel.load();
  }

  build() {
    List({ scroller: scrollers.hotSearch }) {
      ListItem() { Row().height(CommonConstants.TITLE_BAR_HEIGHT_VP) }
        .margin({ bottom: $r('app.float.space_l') })
      if (this.viewModel.state === LoadState.LOADING) {
        ListItem() { LoadingProgress().width('100%').margin($r('app.float.space_xl')) }
      } else if (this.viewModel.state === LoadState.ERROR) {
        ListItem() {
          Column({ space: $r('app.float.space_m') }) {
            Text(this.viewModel.errorMessage.length > 0 ? this.viewModel.errorMessage :
              $r('app.string.error_api_unavailable')).fontColor($r('app.color.hm_error'))
            Button($r('app.string.action_retry')).buttonStyle(ButtonStyleMode.TEXTUAL)
              .onClick(() => this.viewModel.load())
          }.width('100%').padding($r('app.float.space_xl'))
        }
      } else if (this.viewModel.state === LoadState.EMPTY) {
        ListItem() { Text($r('app.string.empty_hot_search')).width('100%').textAlign(TextAlign.Center) }
      }
      ForEach(this.viewModel.topics, (topic: WeiboHotTopic) => {
        ListItem() {
          Row({ space: $r('app.float.space_m') }) {
            Text(topic.rank.toString()).fontColor(topic.rank <= 3 ? ThemeColorController.brand() :
              $r('app.color.hm_text_secondary')).width($r('app.float.button_height'))
            Column({ space: $r('app.float.space_xs') }) {
              Text(topic.word).fontColor($r('app.color.hm_text_primary')).fontWeight(FontWeight.Medium)
              if (topic.heat > 0) {
                Text(topic.heat.toString()).fontSize($r('app.float.font_size_metric'))
                  .fontColor($r('app.color.hm_text_secondary'))
              }
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            if (topic.label.length > 0) {
              Text(topic.label).fontSize($r('app.float.font_size_metric')).fontColor(ThemeColorController.brand())
            }
          }.width('100%').padding($r('app.float.space_m'))
        }
      }, (topic: WeiboHotTopic) => topic.word)
      if (this.viewModel.topics.length === 0) {
        ListItem() { Row().height(CommonConstants.shortContentScrollDistance(this.viewportHeightVp)) }
      }
    }
    .width('100%').height('100%')
    .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
    .contentEndOffset(this.viewModel.topics.length <= 1 ? this.viewportHeightVp : 0)
    .onAreaChange((_oldArea: Area, newArea: Area) => this.viewportHeightVp = Number(newArea.height))
    .scrollBar(BarState.Off)
  }
}
