import { describe, it, expect } from '@ohos/hypium';
import { PostDateFormatter, PostDateKind } from '../../../main/ets/service/PostDateFormatter';

export default function postDateFormatterTest() {
  describe('PostDateFormatter', () => {
    it('formats_recent_and_old_dates', 0, () => {
      const now: number = Date.parse('2026-11-26T12:00:00+08:00');
      expect(PostDateFormatter.friendly('Thu Nov 26 11:55:00 +0800 2026', now).kind)
        .assertEqual(PostDateKind.MINUTES_AGO);
      expect(PostDateFormatter.friendly('Thu Nov 26 11:55:00 +0800 2026', now).first).assertEqual(5);
      expect(PostDateFormatter.friendly('Wed Nov 25 08:00:00 +0800 2026', now).kind)
        .assertEqual(PostDateKind.YESTERDAY);
      expect(PostDateFormatter.friendly('Mon Jul 07 14:10:43 +0800 2025', now).kind)
        .assertEqual(PostDateKind.YEAR_MONTH_DAY);
    });

    it('keeps_unparseable_source_text', 0, () => {
      expect(PostDateFormatter.friendly('unknown date', 0).kind).assertEqual(PostDateKind.RAW);
      expect(PostDateFormatter.friendly('unknown date', 0).raw).assertEqual('unknown date');
    });
  });
}
