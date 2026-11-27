import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import {
  EntitySearchRouteParam,
  SocialTextEntity,
  SocialTextEntityKind,
  UserRouteParam
} from '../model/WeiboModels';
import { RouterConstants } from '../common/constants/RouterConstants';
import { contentActionService } from './ContentActionService';
import { notificationService } from './NotificationService';

export class SocialEntityActionService {
  async open(entity: SocialTextEntity, navPathStack: NavPathStack,
    hostContext: common.UIAbilityContext, uiContext: UIContext): Promise<void> {
    if (entity.kind === SocialTextEntityKind.LINK) {
      if (!await contentActionService.openLink(hostContext, entity.url)) {
        notificationService.showError(uiContext, $r('app.string.notice_open_failed'));
      }
      return;
    }
    if (entity.kind === SocialTextEntityKind.MENTION && entity.userId.length > 0) {
      navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_PROFILE,
        new UserRouteParam(entity.userId, entity.displayText)));
      return;
    }
    navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_ENTITY_SEARCH,
      new EntitySearchRouteParam(entity.query, entity.displayText)));
  }
}

export const socialEntityActionService: SocialEntityActionService = new SocialEntityActionService();
