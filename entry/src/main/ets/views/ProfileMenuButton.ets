import { common } from '@kit.AbilityKit';
import { WeiboUser } from '../model/WeiboModels';
import { MenuItemSpec, MenuSpec } from '../common/components/MenuSpec';
import { AppMenu } from '../common/components/AppMenu';
import { contentActionService } from '../service/ContentActionService';
import { notificationService } from '../service/NotificationService';
import { MaterialController } from '../service/MaterialController';
import { appSettings } from '../model/AppSettings';

@ComponentV2
export struct ProfileMenuButton {
  @Param user: WeiboUser = new WeiboUser();

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async copyProfileLink(): Promise<void> {
    const success: boolean = await contentActionService.copy(contentActionService.profileUrl(this.user.id));
    if (success) {
      notificationService.showSuccess(this.getUIContext(), $r('app.string.notice_copied'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_copy_failed'));
    }
  }

  private async shareProfile(): Promise<void> {
    const success: boolean = await contentActionService.shareText(this.hostContext(), this.user.name,
      contentActionService.profileShareText(this.user.id, this.user.name));
    if (!success) {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_share_failed'));
    }
  }

  private async openProfileLink(): Promise<void> {
    const success: boolean = await contentActionService.openLink(this.hostContext(),
      contentActionService.profileUrl(this.user.id));
    if (!success) {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_open_failed'));
    }
  }

  private profileMenuSpec(): MenuSpec {
    const hasId: boolean = this.user.id.length > 0;
    return MenuSpec.fromItems([
      new MenuItemSpec('copy-link', $r('app.string.action_copy_link'), () => this.copyProfileLink())
        .withEnabled(hasId),
      new MenuItemSpec('share', $r('app.string.action_share'), () => this.shareProfile())
        .withEnabled(hasId),
      new MenuItemSpec('open', $r('app.string.action_open_browser'), () => this.openProfileLink())
        .withEnabled(hasId)
    ]);
  }

  @Builder
  ProfileMenu() {
    AppMenu(this.profileMenuSpec());
  }

  build() {
    Button() {
      SymbolGlyph($r('sys.symbol.ellipsis_circle'))
        .fontSize($r('app.float.icon_size_small'))
        .fontColor([$r('app.color.hm_text_secondary')])
    }
    .buttonStyle(ButtonStyleMode.TEXTUAL)
    .width($r('app.float.button_height'))
    .height($r('app.float.button_height'))
    .accessibilityText($r('app.string.action_more'))
    .bindMenu(this.ProfileMenu(), MaterialController.menuOptions(appSettings.immersiveOn))
    .bindContextMenu(this.ProfileMenu(), ResponseType.LongPress)
  }
}
