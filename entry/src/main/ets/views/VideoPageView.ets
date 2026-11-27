import { AppVideoPlayer } from '../common/components/AppVideoPlayer';
import { VideoRouteParam } from '../model/WeiboModels';
import { safeArea } from '../service/SafeAreaController';
import { ResponsiveContent } from './ResponsiveContent';

@ComponentV2
export struct VideoPageView {
  @Param routeParam: VideoRouteParam = new VideoRouteParam('', '');

  build() {
    ResponsiveContent() {
      Column({ space: $r('app.float.space_l') }) {
        Row().height(safeArea.contentTopInsetVp)
        AppVideoPlayer({
          videoUrl: this.routeParam.videoUrl,
          posterUrl: this.routeParam.posterUrl,
          playerHeight: $r('app.float.video_height'),
          playerRadius: $r('app.float.radius_card'),
          coordinateInlinePlayback: true
        })
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('app.float.space_l'), right: $r('app.float.space_l') })
    }
  }
}
