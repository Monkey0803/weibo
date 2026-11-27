import { common } from '@kit.AbilityKit';
import { SocialTextEntity } from '../../model/WeiboModels';
import { socialEntityActionService } from '../../service/SocialEntityActionService';
import { socialEntityInteractionGuard } from '../../service/SocialEntityInteractionGuard';

class SocialRichTextPart {
  readonly key: string;
  readonly text: string;
  readonly entity?: SocialTextEntity;

  constructor(key: string, text: string, entity?: SocialTextEntity) {
    this.key = key;
    this.text = text;
    this.entity = entity;
  }
}

@ComponentV2
export struct SocialRichText {
  @Param text: string = '';
  @Param entities: SocialTextEntity[] = [];
  @Param fontSize: Resource = $r('app.float.font_size_body');
  @Param fontColor: ResourceColor = $r('app.color.hm_text_primary');
  @Param lineHeight: Resource = $r('app.float.space_xl');
  @Param maxLines: number = 100000;
  @Param brandColor: ResourceColor = $r('app.color.hm_brand');
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Event onPlainTap: () => void = (): void => {};

  private parts(): SocialRichTextPart[] {
    const parts: SocialRichTextPart[] = [];
    let cursor: number = 0;
    for (let index: number = 0; index < this.entities.length; index++) {
      const entity: SocialTextEntity = this.entities[index];
      const end: number = entity.start + entity.length;
      if (entity.start < cursor || entity.length <= 0 || end > this.text.length) {
        continue;
      }
      if (entity.start > cursor) {
        parts.push(new SocialRichTextPart(`plain-${cursor}-${entity.start}`,
          this.text.substring(cursor, entity.start)));
      }
      parts.push(new SocialRichTextPart(`entity-${entity.start}-${end}`,
        this.text.substring(entity.start, end), entity));
      cursor = end;
    }
    if (cursor < this.text.length) {
      parts.push(new SocialRichTextPart(`plain-${cursor}-${this.text.length}`, this.text.substring(cursor)));
    }
    return parts;
  }

  private openEntity(entity: SocialTextEntity): void {
    socialEntityInteractionGuard.blockCurrentClick();
    const hostContext: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    socialEntityActionService.open(entity, this.navPathStack, hostContext, this.getUIContext());
  }

  build() {
    Text() {
      ForEach(this.parts(), (part: SocialRichTextPart) => {
        if (part.entity !== undefined) {
          Span(part.text)
            .fontColor(this.brandColor)
            .fontWeight(FontWeight.Medium)
            .onClick((_event: ClickEvent): void => {
              this.openEntity(part.entity as SocialTextEntity);
            })
        } else {
          Span(part.text)
        }
      }, (part: SocialRichTextPart): string => part.key)
    }
    .fontSize(this.fontSize)
    .fontColor(this.fontColor)
    .lineHeight(this.lineHeight)
    .fontWeight(FontWeight.Regular)
    .maxLines(this.maxLines)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
    .width('100%')
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Up) {
        event.stopPropagation();
      }
    })
    .onClick((): void => {
      if (!socialEntityInteractionGuard.blocked()) {
        this.onPlainTap();
      }
    })
  }
}
