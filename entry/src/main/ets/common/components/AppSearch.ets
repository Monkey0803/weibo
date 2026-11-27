import { SymbolGlyphModifier } from '@kit.ArkUI';
import { appSettings } from '../../model/AppSettings';
import { MaterialController } from '../../service/MaterialController';
import { ThemeColorController } from '../../service/ThemeColorController';

@ComponentV2
export struct AppSearch {
  @Param text: string = '';
  @Param placeholder: ResourceStr = '';
  @Param useImmersiveMaterial: boolean = false;
  @Event onChange: (value: string) => void = () => {};
  @Event onSubmit: (value: string) => void = () => {};
  @Event onSearchFocus: () => void = () => {};
  @Event onSearchBlur: () => void = () => {};
  private controller: SearchController = new SearchController();

  private materialActive(): boolean {
    return this.useImmersiveMaterial && MaterialController.materialUsable() && appSettings.immersiveOn;
  }

  private searchSymbol(): SymbolGlyphModifier {
    const symbol: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.magnifyingglass'));
    symbol.fontColor([this.materialActive() ? $r('sys.color.font_secondary') : ThemeColorController.brand()]);
    return symbol;
  }

  private clearSymbol(): SymbolGlyphModifier {
    const symbol: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark_circle_fill'));
    symbol.fontColor([this.materialActive() ? $r('sys.color.font_primary') : ThemeColorController.brand()]);
    return symbol;
  }

  @Builder
  SearchField(background: ResourceColor) {
    Search({ value: this.text, placeholder: this.placeholder, controller: this.controller })
      .width('100%')
      .height($r('app.float.title_search_height'))
      .borderRadius($r('app.float.radius_card'))
      .backgroundColor(background)
      .placeholderColor(this.materialActive() ? $r('sys.color.font_secondary') : $r('app.color.hm_text_secondary'))
      .textFont({ size: $r('app.float.font_size_body') })
      .fontColor(this.materialActive() ? $r('sys.color.font_primary') : $r('app.color.hm_text_primary'))
      .caretStyle({ color: ThemeColorController.brand() })
      .selectedBackgroundColor(ThemeColorController.soft())
      .searchIcon(this.searchSymbol())
      .cancelButton({ style: CancelButtonStyle.INPUT, icon: this.clearSymbol() })
      .onChange((value: string) => this.onChange(value))
      .onSubmit((value: string) => this.onSubmit(value))
      .onFocus(() => this.onSearchFocus())
      .onBlur(() => this.onSearchBlur())
  }

  build() {
    if (this.useImmersiveMaterial) {
      Stack() {
        this.SearchField(Color.Transparent)
      }
      .width('100%')
      .height($r('app.float.title_search_height'))
      .backgroundColor($r('app.color.hm_search_background'))
      .borderRadius($r('app.float.radius_card'))
      .systemMaterial(MaterialController.glassMaterial(appSettings.immersiveOn))
    } else {
      this.SearchField($r('app.color.hm_search_background'))
    }
  }
}
