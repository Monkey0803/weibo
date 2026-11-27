import { describe, expect, it } from '@ohos/hypium';
import {
  acceptsFullscreenSession,
  canActivateFullscreen,
  formatVideoPlaybackTime,
  shouldResumeInlineAfterFullscreen,
  VideoFullscreenPhase
} from '../../../main/ets/common/components/AppVideoPlayer';

export default function videoPlayerSupportTest() {
  describe('VideoPlayerSupport', () => {
    it('formats_short_duration', 0, () => {
      expect(formatVideoPlaybackTime(65.9)).assertEqual('1:05');
    });

    it('formats_hour_duration', 0, () => {
      expect(formatVideoPlaybackTime(3661)).assertEqual('1:01:01');
    });

    it('normalizes_invalid_duration', 0, () => {
      expect(formatVideoPlaybackTime(-1)).assertEqual('0:00');
    });

    it('activates_fullscreen_only_after_cover_and_video_are_ready', 0, () => {
      expect(canActivateFullscreen(VideoFullscreenPhase.ENTERING, false, true, false)).assertFalse();
      expect(canActivateFullscreen(VideoFullscreenPhase.ENTERING, true, false, false)).assertFalse();
      expect(canActivateFullscreen(VideoFullscreenPhase.ENTERING, true, true, false)).assertTrue();
    });

    it('does_not_repeat_fullscreen_transfer_after_rotation_reprepare', 0, () => {
      expect(canActivateFullscreen(VideoFullscreenPhase.ENTERING, true, true, true)).assertFalse();
      expect(canActivateFullscreen(VideoFullscreenPhase.ACTIVE, true, true, false)).assertFalse();
    });

    it('rejects_stale_or_disposed_fullscreen_callbacks', 0, () => {
      expect(acceptsFullscreenSession(3, 2, VideoFullscreenPhase.ENTERING)).assertFalse();
      expect(acceptsFullscreenSession(3, 3, VideoFullscreenPhase.INLINE)).assertFalse();
      expect(acceptsFullscreenSession(3, 3, VideoFullscreenPhase.DISPOSED)).assertFalse();
      expect(acceptsFullscreenSession(3, 3, VideoFullscreenPhase.ACTIVE)).assertTrue();
    });

    it('uses_latest_playback_intent_when_leaving_active_fullscreen', 0, () => {
      expect(shouldResumeInlineAfterFullscreen(VideoFullscreenPhase.ACTIVE, false, true)).assertFalse();
      expect(shouldResumeInlineAfterFullscreen(VideoFullscreenPhase.ACTIVE, true, false)).assertTrue();
    });

    it('keeps_entry_playback_intent_when_fullscreen_exits_before_activation', 0, () => {
      expect(shouldResumeInlineAfterFullscreen(VideoFullscreenPhase.ENTERING, false, true)).assertTrue();
      expect(shouldResumeInlineAfterFullscreen(VideoFullscreenPhase.ENTERING, true, false)).assertFalse();
    });
  });
}
