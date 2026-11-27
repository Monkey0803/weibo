import { describe, expect, it } from '@ohos/hypium';
import { SafeAreaController } from '../../../main/ets/service/SafeAreaController';

export default function safeAreaControllerTest() {
  describe('SafeAreaController', () => {
    it('uses_larger_system_or_cutout_inset_for_video_controls', 0, () => {
      expect(SafeAreaController.videoInset(32, 18)).assertEqual(32);
      expect(SafeAreaController.videoInset(0, 28)).assertEqual(28);
    });

    it('keeps_zero_video_inset_without_system_or_cutout_area', 0, () => {
      expect(SafeAreaController.videoInset(0, 0)).assertEqual(0);
    });
  });
}
