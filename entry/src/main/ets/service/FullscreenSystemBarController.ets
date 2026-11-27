import { window } from '@kit.ArkUI';

const SYSTEM_BAR_RETRY_COUNT: number = 3;
const SYSTEM_BAR_RETRY_DELAY_MS: number = 250;
const SYSTEM_BAR_RETRY_MAX_DELAY_MS: number = 4000;

export abstract class FullscreenSystemBarTarget {
  abstract setEnabled(name: window.SpecificSystemBar, enabled: boolean): Promise<boolean>;
}

class WindowSystemBarTarget extends FullscreenSystemBarTarget {
  private mainWindow: window.Window;

  constructor(mainWindow: window.Window) {
    super();
    this.mainWindow = mainWindow;
  }

  async setEnabled(name: window.SpecificSystemBar, enabled: boolean): Promise<boolean> {
    try {
      await this.mainWindow.setSpecificSystemBarEnabled(name, enabled, false);
      return true;
    } catch (_error) {
      return false;
    }
  }
}

/**
 * 串行协调全屏播放器对主窗口系统栏的修改。
 *
 * 系统栏是窗口级状态，而信息流里可能同时存在多个播放器实例，因此不能由组件实例
 * 各自直接恢复。owner 只允许最新一次全屏会话修改最终状态，串行队列则保证旧恢复
 * 不会晚于新隐藏落地。
 */
export class FullscreenSystemBarController {
  private nextOwner: number = 0;
  private activeOwner: number = 0;
  private activeTarget: FullscreenSystemBarTarget | undefined = undefined;
  private operation: Promise<void> = Promise.resolve();
  private restoreRetryTimer: number = -1;
  private restoreRetryDelayMs: number = SYSTEM_BAR_RETRY_DELAY_MS;

  acquire(mainWindow: window.Window): number {
    return this.acquireTarget(new WindowSystemBarTarget(mainWindow));
  }

  /** 注入窗口目标，供窗口适配层和异步生命周期测试共享同一套所有权逻辑。 */
  acquireTarget(target: FullscreenSystemBarTarget): number {
    this.clearRestoreRetry();
    const owner: number = ++this.nextOwner;
    this.activeOwner = owner;
    this.activeTarget = target;
    this.enqueue(async (): Promise<void> => {
      if (this.activeOwner !== owner) {
        return;
      }
      await this.applyWithRetry(target, false);
    });
    return owner;
  }

  release(owner: number): Promise<void> {
    if (owner <= 0 || this.activeOwner !== owner) {
      return this.operation;
    }
    this.activeOwner = 0;
    const target: FullscreenSystemBarTarget | undefined = this.activeTarget;
    return this.enqueue(async (): Promise<void> => {
      if (this.activeOwner !== 0 || target === undefined) {
        return;
      }
      const restored: boolean = await this.applyWithRetry(target, true);
      if (restored && this.activeOwner === 0 && this.activeTarget === target) {
        this.activeTarget = undefined;
        this.restoreRetryDelayMs = SYSTEM_BAR_RETRY_DELAY_MS;
      } else if (!restored && this.activeOwner === 0 && this.activeTarget === target) {
        this.scheduleRestoreRetry(target);
      }
    });
  }

  /** 等待已经排队的窗口操作完成，供生命周期协调和异步回归测试使用。 */
  whenIdle(): Promise<void> {
    return this.operation;
  }

  /** Ability / Window 销毁时停止补偿任务并释放旧窗口引用。 */
  reset(): void {
    this.clearRestoreRetry();
    this.activeOwner = 0;
    this.activeTarget = undefined;
  }

  private enqueue(action: () => Promise<void>): Promise<void> {
    const request: Promise<void> = this.operation
      .catch((): void => {
      })
      .then(action);
    this.operation = request;
    return request;
  }

  private clearRestoreRetry(): void {
    if (this.restoreRetryTimer >= 0) {
      clearTimeout(this.restoreRetryTimer);
      this.restoreRetryTimer = -1;
    }
    this.restoreRetryDelayMs = SYSTEM_BAR_RETRY_DELAY_MS;
  }

  /** 窗口切换期间恢复可能暂时失败；保留恢复义务，直到成功或被新全屏 owner 接管。 */
  private scheduleRestoreRetry(target: FullscreenSystemBarTarget): void {
    if (this.restoreRetryTimer >= 0) {
      return;
    }
    const retryDelayMs: number = this.restoreRetryDelayMs;
    this.restoreRetryDelayMs = Math.min(SYSTEM_BAR_RETRY_MAX_DELAY_MS, retryDelayMs * 2);
    this.restoreRetryTimer = setTimeout((): void => {
      this.restoreRetryTimer = -1;
      this.enqueue(async (): Promise<void> => {
        if (this.activeOwner !== 0 || this.activeTarget !== target) {
          return;
        }
        const restored: boolean = await this.applyWithRetry(target, true);
        if (restored && this.activeOwner === 0 && this.activeTarget === target) {
          this.activeTarget = undefined;
          this.restoreRetryDelayMs = SYSTEM_BAR_RETRY_DELAY_MS;
          return;
        }
        if (this.activeOwner === 0 && this.activeTarget === target) {
          this.scheduleRestoreRetry(target);
        }
      });
    }, retryDelayMs);
  }

  private async applyWithRetry(target: FullscreenSystemBarTarget, enabled: boolean): Promise<boolean> {
    for (let attempt: number = 0; attempt < SYSTEM_BAR_RETRY_COUNT; attempt += 1) {
      if (await this.apply(target, enabled)) {
        return true;
      }
    }
    return false;
  }

  private async apply(target: FullscreenSystemBarTarget, enabled: boolean): Promise<boolean> {
    const results: boolean[] = await Promise.all([
      this.setEnabled(target, 'status', enabled),
      this.setEnabled(target, 'navigation', enabled),
      this.setEnabled(target, 'navigationIndicator', enabled)
    ]);
    return results[0] && results[1] && results[2];
  }

  private async setEnabled(target: FullscreenSystemBarTarget, name: window.SpecificSystemBar,
    enabled: boolean): Promise<boolean> {
    try {
      return await target.setEnabled(name, enabled);
    } catch (_error) {
      return false;
    }
  }
}

export const fullscreenSystemBars: FullscreenSystemBarController = new FullscreenSystemBarController();
