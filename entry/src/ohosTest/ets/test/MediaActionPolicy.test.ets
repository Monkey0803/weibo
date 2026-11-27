import { describe, it, expect } from '@ohos/hypium';
import { MediaActionKind, MediaActionPolicy } from '../../../main/ets/service/MediaActionService';

export default function mediaActionPolicyTest() {
  describe('MediaActionPolicy', () => {
    it('applies_image_and_video_size_limits', 0, () => {
      expect(MediaActionPolicy.maxBytes(MediaActionKind.IMAGE)).assertEqual(64 * 1024 * 1024);
      expect(MediaActionPolicy.maxBytes(MediaActionKind.VIDEO)).assertEqual(500 * 1024 * 1024);
    });

    it('keeps_supported_extensions_and_uses_safe_defaults', 0, () => {
      expect(MediaActionPolicy.extension('https://example.com/a.WEBP?size=large',
        MediaActionKind.IMAGE)).assertEqual('webp');
      expect(MediaActionPolicy.extension('https://example.com/play', MediaActionKind.VIDEO)).assertEqual('mp4');
    });

    it('accepts_expected_content_types_and_octet_stream', 0, () => {
      expect(MediaActionPolicy.acceptsContentType('image/jpeg', MediaActionKind.IMAGE)).assertTrue();
      expect(MediaActionPolicy.acceptsContentType('video/mp4', MediaActionKind.VIDEO)).assertTrue();
      expect(MediaActionPolicy.acceptsContentType('application/octet-stream', MediaActionKind.VIDEO)).assertTrue();
      expect(MediaActionPolicy.acceptsContentType('text/html', MediaActionKind.IMAGE)).assertFalse();
    });
  });
}
