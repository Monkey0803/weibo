import { SocialTextEntity } from '../../model/WeiboModels';

@ComponentV2
export struct SocialRichText {
  @Param text: string = '';
  @Param entities: SocialTextEntity[] = [];
  @Param fontSize: Resource = $r('app.float.font_size_body');
  @Param fontColor: ResourceColor = $r('app.color.hm_text_primary');
  @Param lineHeight: Resource = $r('app.float.space_xl');
  @Param maxLines: number = 100000;
  @Param brandColor: ResourceColor = $r('app.color.hm_brand');
  @Param pressedColor: ResourceColor = $r('app.color.hm_brand_pressed');
  @Event onEntityTap: (entity: SocialTextEntity) => void = (_entity: SocialTextEntity): void => {};
  @Event onEntityTouchChange: (active: boolean) => void = (_active: boolean): void => {};
  @Local pressedStart: number = -1;
  private controller: TextController = new TextController();

  aboutToAppear(): void {
    this.refreshStyledText();
  }

  @Monitor('text', 'entities', 'brandColor', 'pressedColor', 'pressedStart')
  onContentChanged(): void {
    this.refreshStyledText();
  }

  private styledText(): MutableStyledString {
    const styled: MutableStyledString = new MutableStyledString(this.text);
    for (let index: number = 0; index < this.entities.length; index++) {
      const entity: SocialTextEntity = this.entities[index];
      if (entity.start < 0 || entity.length <= 0 || entity.start + entity.length > this.text.length) {
        continue;
      }
      const textStyle: SpanStyle = {
        start: entity.start,
        length: entity.length,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({
          fontColor: this.pressedStart === entity.start ? this.pressedColor : this.brandColor,
          fontWeight: FontWeight.Medium
        })
      };
      const gestureStyle: SpanStyle = {
        start: entity.start,
        length: entity.length,
        styledKey: StyledStringKey.GESTURE,
        styledValue: new GestureStyle({
          onClick: (_event: ClickEvent): void => {
            this.pressedStart = -1;
            this.onEntityTap(entity);
          },
          onTouch: (event: TouchEvent): void => {
            event.stopPropagation();
            if (event.type === TouchType.Down) {
              this.pressedStart = entity.start;
              this.onEntityTouchChange(true);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.pressedStart = -1;
              this.onEntityTouchChange(false);
            }
          }
        })
      };
      styled.setStyle(textStyle);
      styled.setStyle(gestureStyle);
    }
    return styled;
  }

  private refreshStyledText(): void {
    this.controller.setStyledString(this.styledText());
  }

  build() {
    Text(this.text, { controller: this.controller })
      .fontSize(this.fontSize)
      .fontColor(this.fontColor)
      .lineHeight(this.lineHeight)
      .fontWeight(FontWeight.Regular)
      .maxLines(this.maxLines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
  }
}
