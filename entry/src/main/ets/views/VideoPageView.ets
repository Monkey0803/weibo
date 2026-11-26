import { VideoRouteParam } from '../model/WeiboModels';
import { safeArea } from '../service/SafeAreaController';
import { ResponsiveContent } from './ResponsiveContent';

@ComponentV2
export struct VideoPageView {
  @Param routeParam: VideoRouteParam = new VideoRouteParam('', '');
  @Local failed: boolean = false;
  private controller: VideoController = new VideoController();

  build() {
    ResponsiveContent() {
      Column({ space: $r('app.float.space_l') }) {
        Row().height(safeArea.contentTopInsetVp)
        Video({ src: this.routeParam.videoUrl, previewUri: this.routeParam.posterUrl, controller: this.controller })
          .width('100%')
          .height($r('app.float.video_height'))
          .autoPlay(false)
          .controls(true)
          .objectFit(ImageFit.Contain)
          .backgroundColor($r('app.color.hm_video_background'))
          .borderRadius($r('app.float.radius_card'))
          .onError(() => this.failed = true)
        if (this.failed) {
          Text($r('app.string.video_error')).fontColor($r('app.color.hm_error'))
        }
      }
      .width('100%').height('100%')
      .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
    }
  }
}
