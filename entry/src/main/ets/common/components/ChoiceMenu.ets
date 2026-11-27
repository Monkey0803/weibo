import { ChoiceOption, ChoiceSet } from '../../model/SettingsOptions';
import { MenuItemSpec, MenuSectionSpec, MenuSpec } from './MenuSpec';

export function choiceMenu(choice: ChoiceSet, currentId: string, onPick: (id: string) => void): MenuSpec {
  const items: MenuItemSpec[] = [];
  for (let optionIndex: number = 0; optionIndex < choice.options.length; optionIndex += 1) {
    const option: ChoiceOption = choice.options[optionIndex];
    const item: MenuItemSpec = new MenuItemSpec(option.id, option.label, () => onPick(option.id));
    if (option.id === currentId) {
      item.markSelected();
    }
    items.push(item);
  }
  return new MenuSpec([new MenuSectionSpec(items)], $r('app.float.choice_menu_width'));
}
