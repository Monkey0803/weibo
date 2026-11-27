import { ChoiceSet, THEME_OPTIONS } from '../model/SettingsOptions';
import { appSettings } from '../model/AppSettings';
import { MaterialController } from '../service/MaterialController';
import { ThemeColorController } from '../service/ThemeColorController';
import { AppMenu } from '../common/components/AppMenu';
import { choiceMenu } from '../common/components/ChoiceMenu';
import { AppIcon } from './AppIcon';

function settingsChoiceMenuOptions(immersiveOn: boolean): MenuOptions {
  const options: MenuOptions = MaterialController.menuOptions(immersiveOn);
  options.placement = Placement.BottomRight;
  return options;
}

/** 设置页通用的响应式单选行。 */
@ComponentV2
export struct SettingsOptionRow {
  @Param icon: Resource = $r('app.media.icon_rings');
  @Param title: ResourceStr = '';
  @Param choice: ChoiceSet = THEME_OPTIONS;
  @Param currentId: string = '';
  @Event onPick: (id: string) => void = (_id: string): void => {};

  build() {
    Row() {
      Row({ space: $r('app.float.space_m') }) {
        AppIcon({
          source: this.icon,
          iconSize: $r('app.float.icon_size'),
          tint: ThemeColorController.brand()
        })
        Text(this.title)
          .fontSize($r('app.float.font_size_body'))
          .fontColor($r('app.color.hm_text_primary'))
      }
      Blank()
      Text(this.choice.labelOf(this.currentId))
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_secondary'))
      AppIcon({
        source: $r('app.media.icon_chevron_down'),
        iconSize: $r('app.float.icon_size_small'),
        tint: $r('app.color.hm_text_secondary')
      })
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
    .bindMenu(AppMenu(choiceMenu(this.choice, this.currentId, this.onPick)),
      settingsChoiceMenuOptions(appSettings.immersiveOn))
  }
}
