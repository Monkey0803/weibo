import { ChoiceOption, VIDEO_PLAYBACK_RATE_OPTIONS } from '../../model/SettingsOptions';
import { MenuItemSpec, MenuSectionSpec } from './MenuSpec';

/** 构造视频菜单中的临时倍速分组；选择结果只由当前视频组件持有。 */
export function videoPlaybackMenuSection(currentId: string,
  onPick: (id: string) => void): MenuSectionSpec {
  const normalizedId: string = VIDEO_PLAYBACK_RATE_OPTIONS.normalize(currentId);
  const items: MenuItemSpec[] = [];
  for (let index: number = 0; index < VIDEO_PLAYBACK_RATE_OPTIONS.options.length; index += 1) {
    const option: ChoiceOption = VIDEO_PLAYBACK_RATE_OPTIONS.options[index];
    const item: MenuItemSpec = new MenuItemSpec('video-speed-' + option.id, option.label,
      () => onPick(option.id));
    if (option.id === normalizedId) {
      item.markSelected();
    }
    items.push(item);
  }
  return new MenuSectionSpec(items);
}
