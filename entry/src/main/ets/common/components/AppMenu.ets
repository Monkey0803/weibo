import { LengthMetrics } from '@kit.ArkUI';
import { MenuItemSpec, MenuSectionSpec, MenuSpec } from './MenuSpec';
import { ThemeColorController } from '../../service/ThemeColorController';

const APP_MENU_DIVIDER_INSET: LengthMetrics = LengthMetrics.vp(12);

function appMenuItemColor(item: MenuItemSpec): ResourceColor {
  if (item.selected) {
    return ThemeColorController.brand();
  }
  return item.danger ? $r('app.color.hm_danger') : $r('app.color.hm_text_primary');
}

function appMenuIconColor(item: MenuItemSpec): ResourceColor {
  return item.danger ? $r('app.color.hm_danger') : ThemeColorController.brand();
}

@Builder
function AppMenuRow(item: MenuItemSpec) {
  Stack() {
    Row({ space: $r('app.float.space_s') }) {
      if (item.icon !== undefined) {
        SymbolGlyph(item.icon)
          .fontSize($r('app.float.icon_size'))
          .fontColor([appMenuIconColor(item)])
      }
      Text(item.label)
        .fontSize($r('app.float.font_size_body'))
        .fontWeight(item.selected ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(appMenuItemColor(item))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(item.selected ? ThemeColorController.soft() : $r('app.color.hm_page_transparent'))
    .borderRadius($r('app.float.radius_card'))
  }
  .width('100%')
  .height($r('app.float.menu_item_height'))
  .onClick(() => {
    if (item.itemEnabled) {
      item.action();
    }
  })
}

@Builder
function AppMenuRows(section: MenuSectionSpec) {
  ForEach(section.items, (item: MenuItemSpec) => {
    MenuItem(AppMenuRow(item))
      .enabled(item.itemEnabled)
      .accessibilityChecked(item.selected)
  }, (item: MenuItemSpec) => item.key())
}

/** 统一的下拉菜单和长按菜单渲染入口。 */
@Builder
export function AppMenu(spec: MenuSpec) {
  Menu() {
    if (spec.sections.length === 1 && spec.sections[0].header === undefined) {
      AppMenuRows(spec.sections[0])
    } else {
      ForEach(spec.sections, (section: MenuSectionSpec, sectionIndex: number) => {
        MenuItemGroup({ header: section.header }) {
          AppMenuRows(section)
        }
      }, (_section: MenuSectionSpec, sectionIndex: number) => sectionIndex.toString())
    }
  }
  .width(spec.menuWidth === undefined ? $r('app.float.menu_width') : spec.menuWidth)
  .radius($r('app.float.radius_menu'))
  .menuItemGroupDivider({
    color: $r('app.color.hm_divider'),
    startMargin: APP_MENU_DIVIDER_INSET,
    endMargin: APP_MENU_DIVIDER_INSET
  })
}
