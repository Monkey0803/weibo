import { Result, WeiboPost } from '../model/WeiboModels';
import { ComposeViewModel } from '../viewmodel/ComposeViewModel';
import { notificationService } from '../service/NotificationService';
import { safeArea } from '../service/SafeAreaController';
import { feedViewModel } from '../viewmodel/FeedViewModel';

@ComponentV2
export struct ComposePageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  private viewModel: ComposeViewModel = new ComposeViewModel();

  private async send(): Promise<void> {
    const result: Result<WeiboPost> = await this.viewModel.send();
    if (result.success) {
      feedViewModel.refresh();
      notificationService.showSuccess(this.getUIContext(), $r('app.string.publish_success'));
      this.navPathStack.pop();
    } else {
      notificationService.showError(this.getUIContext(), result.message.length > 0 ? result.message :
        $r('app.string.mutation_failed'));
    }
  }

  build() {
    Column({ space: $r('app.float.space_m') }) {
      Row().height(safeArea.contentTopInsetVp)
      TextArea({ text: this.viewModel.text, placeholder: $r('app.string.compose_hint') })
        .onChange((value: string) => this.viewModel.text = value)
        .layoutWeight(1).width('100%').backgroundColor($r('app.color.hm_card_background'))
        .borderRadius($r('app.float.radius_card')).padding($r('app.float.space_l'))
      Row() {
        Text(this.viewModel.text.length.toString() + ' / 2000').fontSize($r('app.float.font_size_metric'))
          .fontColor($r('app.color.hm_text_secondary'))
        Blank()
        Button($r('app.string.action_publish')).enabled(this.viewModel.canSend()).onClick(() => this.send())
      }.width('100%')
    }.width('100%').height('100%').padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l'),
      bottom: safeArea.contentBottomInsetVp })
  }
}
