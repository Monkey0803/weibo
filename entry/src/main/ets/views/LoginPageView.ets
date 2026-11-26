import { webview } from '@kit.ArkWeb';
import { WeiboSession } from '../service/WeiboSession';
import { authViewModel } from '../viewmodel/AuthViewModel';
import { notificationService } from '../service/NotificationService';
import { safeArea } from '../service/SafeAreaController';
import { ResponsiveContent } from './ResponsiveContent';

@ComponentV2
export struct LoginPageView {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Local checking: boolean = false;
  @Local currentUrl: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  private async finish(): Promise<void> {
    this.checking = true;
    await authViewModel.refresh();
    if (authViewModel.loggedIn) {
      this.navPathStack.pop();
    } else {
      notificationService.show(this.getUIContext(), $r('app.string.login_not_detected'));
    }
    this.checking = false;
  }

  build() {
    ResponsiveContent() {
      Column({ space: $r('app.float.space_m') }) {
        Row().height(safeArea.contentTopInsetVp)
        Text($r('app.string.login_intro'))
          .fontSize($r('app.float.font_size_caption'))
          .fontColor($r('app.color.hm_text_secondary'))
          .width('100%')
        Text($r('app.string.web_login_notice'))
          .fontSize($r('app.float.font_size_caption'))
          .fontColor($r('app.color.hm_brand'))
        Web({ src: WeiboSession.LOGIN_URL, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .layoutWeight(1)
          .width('100%')
          .borderRadius($r('app.float.radius_card'))
          .onPageEnd((event: OnPageEndEvent) => {
            this.currentUrl = event.url;
          })
        Button(this.checking ? $r('app.string.loading') : $r('app.string.login_finished'))
          .width('100%')
          .height($r('app.float.button_height'))
          .enabled(!this.checking)
          .onClick(() => this.finish())
      }
      .width('100%').height('100%')
      .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l'), bottom: $r('app.float.space_l') })
    }
  }
}
