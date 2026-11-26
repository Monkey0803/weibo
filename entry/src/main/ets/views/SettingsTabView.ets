/*
 * SettingsTabView.ets — 设置页签（纯展示 + 事件上报）。
 *
 * 选项切换行（主题 / 语言 / 材质类型 / 沉浸光感材质）用 bindMenu 弹系统 Menu，
 * 布尔行（沉浸光感 / 智感握姿 / 防窥保护）用 Toggle。业务逻辑一律在 SettingsViewModel，
 * 这里只读 appSettings / antiPeep 的状态、把用户操作上报给 ViewModel。
 * 尺寸与颜色全部走 resources。
 */

import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { appSettings } from '../model/AppSettings';
import { ChoiceOption, ChoiceSet, THEME_OPTIONS, LANGUAGE_OPTIONS, MATERIAL_TYPE_OPTIONS, MATERIAL_LEVEL_OPTIONS } from '../model/SettingsOptions';
import { settingsViewModel } from '../viewmodel/SettingsViewModel';
import { MaterialController } from '../service/MaterialController';
import { antiPeep } from '../service/AntiPeep';
import { gripSensor } from '../service/GripSensor';
import { ResponsiveContent } from './ResponsiveContent';
import { scrollers } from '../service/ScrollerRegistry';
import { safeArea } from '../service/SafeAreaController';

@ComponentV2
export struct SettingsTabView {
  /** 内容是否穿透标题栏：true 时顶部预留标题栏高度，首屏内容不被标题栏遮住。 */
  @Param underTitleBar: boolean = false;

  private hostContext(): common.UIAbilityContext {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    return context as common.UIAbilityContext;
  }

  /** 一张选项表的菜单项；当前项带对勾。 */
  private menuFor(choice: ChoiceSet, currentId: string, onPick: (id: string) => void): MenuElement[] {
    const list: MenuElement[] = [];
    for (let i = 0; i < choice.options.length; i += 1) {
      const option: ChoiceOption = choice.options[i];
      const element: MenuElement = {
        value: option.label,
        action: () => {
          onPick(option.id);
        }
      };
      if (option.id === currentId) {
        element.symbolIcon = new SymbolGlyphModifier($r('sys.symbol.checkmark'));
      }
      list.push(element);
    }
    return list;
  }

  @Builder
  SectionTitle(title: ResourceStr) {
    Text(title)
      .fontSize($r('app.float.font_size_section'))
      .fontColor($r('app.color.hm_text_secondary'))
      .margin({ top: $r('app.float.space_xl'), bottom: $r('app.float.space_s'), left: $r('app.float.space_xs') })
  }

  @Builder
  Leading(icon: Resource, title: ResourceStr) {
    Row({ space: $r('app.float.space_m') }) {
      SymbolGlyph(icon)
        .fontSize($r('app.float.icon_size'))
        .fontColor([$r('app.color.hm_brand')])
      Text(title)
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_primary'))
    }
  }

  /**
   * 行首图标的动态样式：开 = 品牌色，关 = 次要色。
   *
   * 用 SymbolGlyphModifier（@kit.ArkUI，API 12+）+ 通用属性 attributeModifier 挂载 —— 图标属性
   * 随状态变，而不是写死一条 fontColor。
   *
   * 注意：本 SDK 的 `new SymbolGlyphModifier(...)` 只接受可选的 src(Resource)，不支持文档示例里的
   * `new SymbolGlyphModifier({ fontSize, fontColor })` 写法；而链式调用返回的是 SymbolGlyphAttribute，
   * 不能直接赋给 SymbolGlyphModifier —— 所以这里先建实例、再赋值式设置属性。
   */
  private static iconModifier(on: boolean): SymbolGlyphModifier {
    const modifier: SymbolGlyphModifier = new SymbolGlyphModifier();
    modifier.fontColor([on ? $r('app.color.hm_brand') : $r('app.color.hm_text_secondary')]);
    return modifier;
  }

  @Builder
  SwitchLeading(icon: Resource, title: ResourceStr, isOn: boolean) {
    Row({ space: $r('app.float.space_m') }) {
      SymbolGlyph(icon)
        .fontSize($r('app.float.icon_size'))
        .attributeModifier(SettingsTabView.iconModifier(isOn))
      Text(title)
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_primary'))
    }
  }

  @Builder
  OptionRow(icon: Resource, title: ResourceStr, choice: ChoiceSet, currentId: string, pick: (id: string) => void) {
    Row() {
      this.Leading(icon, title)
      Blank()
      Text(choice.labelOf(currentId))
        .fontSize($r('app.float.font_size_body'))
        .fontColor($r('app.color.hm_text_secondary'))
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize($r('app.float.icon_size_small'))
        .fontColor([$r('app.color.hm_text_secondary')])
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
    // 菜单沉浸光感：options 里带 systemMaterial（支持时）；不支持则退回普通菜单。
    // 传 immersiveOn —— 关掉时必须用 Material.empty 关闭，不能用 undefined（那只是恢复默认）。
    .bindMenu(this.menuFor(choice, currentId, pick), MaterialController.menuOptions(appSettings.immersiveOn))
  }

  @Builder
  SwitchRow(icon: Resource, title: ResourceStr, isOn: boolean, toggle: (value: boolean) => void) {
    Row() {
      this.SwitchLeading(icon, title, isOn)
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.hm_brand'))
        .onChange((value: boolean) => {
          toggle(value);
        })
    }
    .width('100%')
    .height($r('app.float.row_height'))
    .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
  }

  @Builder
  MaterialCard() {
    Column() {
      this.OptionRow($r('sys.symbol.paintpalette'), $r('app.string.row_theme'), THEME_OPTIONS, appSettings.themeMode,
        (id: string) => {
          settingsViewModel.setTheme(this.hostContext(), id);
        })
      Divider().color($r('app.color.hm_divider'))
      this.SwitchRow($r('sys.symbol.rays'), $r('app.string.row_immersive'), appSettings.immersiveOn,
        (value: boolean) => {
          settingsViewModel.setImmersiveOn(value);
        })
      Divider().color($r('app.color.hm_divider'))
      this.OptionRow($r('sys.symbol.circle'), $r('app.string.row_material_type'), MATERIAL_TYPE_OPTIONS, appSettings.materialType,
        (id: string) => {
          settingsViewModel.setMaterialType(id);
        })
      Divider().color($r('app.color.hm_divider'))
      this.OptionRow($r('sys.symbol.slider_horizontal_2'), $r('app.string.row_material_level'), MATERIAL_LEVEL_OPTIONS, appSettings.materialLevel,
        (id: string) => {
          settingsViewModel.setMaterialLevel(id);
        })
      Divider().color($r('app.color.hm_divider'))
      this.SwitchRow($r('sys.symbol.bolt'), $r('app.string.row_light_effect'), appSettings.lightEffectEnabled,
        (value: boolean) => {
          settingsViewModel.setLightEffectEnabled(value);
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.hm_card_background'))
    .borderRadius($r('app.float.radius_card'))
  }

  build() {
    ResponsiveContent() {
      Scroll(scrollers.settings) {
        Column() {
          // 透明标题栏占位：首屏顶部预留「状态栏 + 标题栏」高度，滚动时随内容上移。
          Row().width('100%')
            .height(this.underTitleBar ? safeArea.contentTopInsetVp : $r('app.float.space_l'))
          this.SectionTitle($r('app.string.section_appearance'))
          this.MaterialCard()

          // 应用级开关（module.json5 metadata）的运行时状态：三态，不要简化成"开 / 关"。
          Text(settingsViewModel.stateCaption)
            .fontSize($r('app.float.font_size_caption'))
            .fontColor($r('app.color.hm_text_secondary'))
            .margin({ top: $r('app.float.space_s'), left: $r('app.float.space_xs') })

          // 设备材质等级（算力档）：只读展示，应用无法设置。
          Text(settingsViewModel.levelCaption)
            .fontSize($r('app.float.font_size_caption'))
            .fontColor($r('app.color.hm_text_secondary'))
            .margin({ top: $r('app.float.space_xs'), left: $r('app.float.space_xs') })

          if (!settingsViewModel.immersiveSupported) {
            Text($r('app.string.aux_material_unsupported'))
              .fontSize($r('app.float.font_size_caption'))
              .fontColor($r('app.color.hm_text_secondary'))
              .margin({ top: $r('app.float.space_s'), left: $r('app.float.space_xs') })
          }

          this.SectionTitle($r('app.string.section_language'))
          Column() {
            this.OptionRow($r('sys.symbol.translate'), $r('app.string.row_language'), LANGUAGE_OPTIONS, appSettings.languageMode,
              (id: string) => {
                settingsViewModel.setLanguage(id);
              })
          }
          .width('100%')
          .backgroundColor($r('app.color.hm_card_background'))
          .borderRadius($r('app.float.radius_card'))

          this.SectionTitle($r('app.string.section_system'))
          Column() {
            this.SwitchRow($r('sys.symbol.hand_raised_hexagon'), $r('app.string.row_grip'), appSettings.gripEnabled,
              (value: boolean) => {
                settingsViewModel.setGripEnabled(value);
              })
            Divider().color($r('app.color.hm_divider'))
            this.SwitchRow($r('sys.symbol.eye_slash'), $r('app.string.row_antipeep'), appSettings.antiPeepEnabled,
              (value: boolean) => {
                settingsViewModel.setAntiPeepEnabled(value, this.hostContext());
              })
          }
          .width('100%')
          .backgroundColor($r('app.color.hm_card_background'))
          .borderRadius($r('app.float.radius_card'))

          if (!gripSensor.supported) {
            Text($r('app.string.aux_grip_unsupported'))
              .fontSize($r('app.float.font_size_caption'))
              .fontColor($r('app.color.hm_text_secondary'))
              .margin({ top: $r('app.float.space_s'), left: $r('app.float.space_xs') })
          }

          if (!antiPeep.supported) {
            Text($r('app.string.aux_antipeep_unsupported'))
              .fontSize($r('app.float.font_size_caption'))
              .fontColor($r('app.color.hm_text_secondary'))
              .margin({ top: $r('app.float.space_s'), left: $r('app.float.space_xs') })
          }

          // barOverlap(true) 时页签栏悬浮叠在内容上：底部预留避让，末行不被遮挡。
          Blank().height(safeArea.contentBottomInsetVp)
        }
        .width('100%')
        .padding({
          left: $r('app.float.space_l'),
          right: $r('app.float.space_l')
        })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      // 内容穿透标题栏：不裁剪，让内容能滚动到标题栏下方（配合动态模糊）。
      .clip(false)
      .backgroundColor($r('app.color.hm_page_transparent'))
    }
  }
}
