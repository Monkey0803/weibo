/*
 * PrivacyVeil.ets — 防窥遮罩（纯展示）。
 *
 * 盖住除页签栏以外的内容，轻点任意位置把「继续查看」事件交给共享的 AntiPeep 控制器。
 */

import { antiPeep } from '../service/AntiPeep';
import { AppIcon } from './AppIcon';

@ComponentV2
export struct PrivacyVeil {
  build() {
    Column({ space: $r('app.float.space_l') }) {
      AppIcon({
        source: $r('app.media.icon_eye_closed'),
        iconSize: $r('app.float.hero_icon_size'),
        tint: $r('app.color.hm_text_primary')
      })
      Text($r('app.string.veil_message'))
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_primary'))
      Text($r('app.string.veil_dismiss'))
        .fontSize($r('app.float.font_size_section'))
        .fontColor($r('app.color.hm_text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.hm_veil_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onClick(() => {
      antiPeep.acknowledge();
    })
  }
}
