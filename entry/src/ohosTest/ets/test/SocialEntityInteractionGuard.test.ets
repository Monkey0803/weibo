import { describe, expect, it } from '@ohos/hypium';
import { SocialEntityInteractionGuard } from '../../../main/ets/service/SocialEntityInteractionGuard';

function nextTask(): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, 0);
  });
}

export default function socialEntityInteractionGuardTest() {
  describe('SocialEntityInteractionGuard', () => {
    it('stays_blocked_until_the_next_task', 0, async (): Promise<void> => {
      const guard: SocialEntityInteractionGuard = new SocialEntityInteractionGuard();
      guard.begin();
      guard.end();
      expect(guard.blocked()).assertTrue();
      await nextTask();
      expect(guard.blocked()).assertFalse();
    });

    it('does_not_let_an_old_release_clear_a_new_interaction', 0, async (): Promise<void> => {
      const guard: SocialEntityInteractionGuard = new SocialEntityInteractionGuard();
      guard.begin();
      guard.end();
      guard.begin();
      await nextTask();
      expect(guard.blocked()).assertTrue();
      guard.end();
      await nextTask();
      expect(guard.blocked()).assertFalse();
    });
  });
}
