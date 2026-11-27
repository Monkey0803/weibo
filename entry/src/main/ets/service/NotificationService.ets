/** 即时操作反馈：按语义选择图标，支持 HDS 普通背板与系统沉浸材质背板。 */
import { ColorMetrics, UIContext } from '@kit.ArkUI';
import { HdsSnackBar, SnackBarIconOptions, SnackBarOperationOptions, SnackBarOperationType,
  SnackBarStyleOptions } from '@kit.UIDesignKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { appSettings } from '../model/AppSettings';
import { MaterialController } from './MaterialController';

export enum NoticeKind {
  SUCCESS = 'success',
  ERROR = 'error',
  INFO = 'info'
}

export class NoticeRequest {
  message: ResourceStr;
  kind: NoticeKind;
  durationMs: number;
  actionText: ResourceStr | undefined;
  onAction: (() => void) | undefined;

  constructor(message: ResourceStr, kind: NoticeKind, durationMs: number,
    actionText?: ResourceStr, onAction?: () => void) {
    this.message = message;
    this.kind = kind;
    this.durationMs = durationMs;
    this.actionText = actionText;
    this.onAction = onAction;
  }
}

export function noticeIcon(kind: NoticeKind): Resource {
  if (kind === NoticeKind.SUCCESS) {
    return $r('sys.symbol.checkmark_circle');
  }
  if (kind === NoticeKind.ERROR) {
    return $r('sys.symbol.exclamationmark_circle');
  }
  return $r('sys.symbol.info_circle');
}

export class NotificationService {
  private snackBar: HdsSnackBar | undefined = undefined;
  private boundContext: UIContext | undefined = undefined;
  private presenter: ((request: NoticeRequest) => void) | undefined = undefined;
  private dismissPresenter: (() => void) | undefined = undefined;

  setPresenter(presenter: ((request: NoticeRequest) => void) | undefined,
    dismissPresenter?: () => void): void {
    this.presenter = presenter;
    this.dismissPresenter = dismissPresenter;
  }

  private ensure(uiContext: UIContext): HdsSnackBar {
    if (this.snackBar === undefined || this.boundContext !== uiContext) {
      this.snackBar = new HdsSnackBar(uiContext);
      this.boundContext = uiContext;
    }
    return this.snackBar;
  }

  private showRequest(uiContext: UIContext, request: NoticeRequest): void {
    try {
      if (appSettings.immersiveOn && MaterialController.materialUsable() && this.presenter !== undefined) {
        this.snackBar?.dismiss();
        this.presenter(request);
        return;
      }
      this.dismissPresenter?.();
      this.showPlain(uiContext, request);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('NotificationService.show failed: ' + error.code.toString());
    }
  }

  showPlain(uiContext: UIContext, request: NoticeRequest): void {
    try {
      const snackBar: HdsSnackBar = this.ensure(uiContext);
      snackBar.dismiss();
      const icon: SnackBarIconOptions = { icon: noticeIcon(request.kind) };
      let actionTaken: boolean = false;
      const operation: SnackBarOperationOptions = request.actionText === undefined || request.onAction === undefined
        ? { operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY }
        : {
          operationType: SnackBarOperationType.TEXT_WITH_CLOSE,
          content: request.actionText,
          onContentClick: () => {
            if (actionTaken) {
              return;
            }
            actionTaken = true;
            snackBar.dismiss();
            request.onAction?.();
          }
        };
      const style: SnackBarStyleOptions = {
        duration: request.durationMs,
        isHeightAdaptive: true,
        backgroundBlurStyle: BlurStyle.NONE,
        backgroundColor: ColorMetrics.resourceColor($r('app.color.hm_card_background'))
      };
      snackBar.show(icon, { content: request.message }, operation, style);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('HdsSnackBar.show failed: ' + error.code.toString());
    }
  }

  showSuccess(uiContext: UIContext, message: ResourceStr): void {
    this.showRequest(uiContext, new NoticeRequest(message, NoticeKind.SUCCESS, 3000));
  }

  showError(uiContext: UIContext, message: ResourceStr): void {
    this.showRequest(uiContext, new NoticeRequest(message, NoticeKind.ERROR, 5000));
  }

  showInfo(uiContext: UIContext, message: ResourceStr): void {
    this.showRequest(uiContext, new NoticeRequest(message, NoticeKind.INFO, 3000));
  }

  showWithAction(uiContext: UIContext, message: ResourceStr, actionText: ResourceStr,
    onAction: () => void, kind: NoticeKind = NoticeKind.INFO): void {
    this.showRequest(uiContext, new NoticeRequest(message, kind, 5000, actionText, onAction));
  }
}

export const notificationService: NotificationService = new NotificationService();
