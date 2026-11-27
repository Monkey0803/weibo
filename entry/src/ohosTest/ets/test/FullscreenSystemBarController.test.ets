import { window } from '@kit.ArkUI';
import { describe, expect, it } from '@ohos/hypium';
import {
  FullscreenSystemBarController,
  FullscreenSystemBarTarget
} from '../../../main/ets/service/FullscreenSystemBarController';

class RecordingSystemBarTarget extends FullscreenSystemBarTarget {
  enabledValues: boolean[] = [];
  failuresRemaining: number = 0;

  setEnabled(_name: window.SpecificSystemBar, enabled: boolean): Promise<boolean> {
    this.enabledValues.push(enabled);
    if (this.failuresRemaining > 0) {
      this.failuresRemaining -= 1;
      return Promise.resolve(false);
    }
    return Promise.resolve(true);
  }
}

export default function fullscreenSystemBarControllerTest() {
  describe('FullscreenSystemBarController', () => {
    it('does_not_restore_an_old_owner_over_a_new_fullscreen', 0, async (): Promise<void> => {
      const controller: FullscreenSystemBarController = new FullscreenSystemBarController();
      const target: RecordingSystemBarTarget = new RecordingSystemBarTarget();
      const ownerA: number = controller.acquireTarget(target);
      await controller.whenIdle();
      const oldRestore: Promise<void> = controller.release(ownerA);
      const ownerB: number = controller.acquireTarget(target);
      await oldRestore;
      await controller.whenIdle();
      expect(target.enabledValues.filter((enabled: boolean): boolean => enabled).length).assertEqual(0);
      await controller.release(ownerB);
      expect(target.enabledValues.filter((enabled: boolean): boolean => enabled).length).assertEqual(3);
    });

    it('retries_transient_restore_failures', 0, async (): Promise<void> => {
      const controller: FullscreenSystemBarController = new FullscreenSystemBarController();
      const target: RecordingSystemBarTarget = new RecordingSystemBarTarget();
      const owner: number = controller.acquireTarget(target);
      await controller.whenIdle();
      target.enabledValues = [];
      target.failuresRemaining = 1;
      await controller.release(owner);
      expect(target.enabledValues.filter((enabled: boolean): boolean => enabled).length).assertEqual(6);
    });

    it('keeps_restore_pending_after_the_immediate_retries_fail', 0, async (): Promise<void> => {
      const controller: FullscreenSystemBarController = new FullscreenSystemBarController();
      const target: RecordingSystemBarTarget = new RecordingSystemBarTarget();
      const owner: number = controller.acquireTarget(target);
      await controller.whenIdle();
      target.enabledValues = [];
      target.failuresRemaining = 9;
      await controller.release(owner);
      target.failuresRemaining = 0;
      await new Promise<void>((resolve: () => void): void => {
        setTimeout(resolve, 350);
      });
      await controller.whenIdle();
      expect(target.enabledValues.length).assertEqual(12);
    });
  });
}
