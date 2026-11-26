import { describe, it, expect } from '@ohos/hypium';
import { WeiboParser } from '../../../main/ets/service/WeiboParser';
import { PageResult, SessionInfo, WeiboPost } from '../../../main/ets/model/WeiboModels';

export default function weiboParserTest() {
  describe('WeiboParser', () => {
    it('parses_and_deduplicates_feed_posts', 0, () => {
      const source: string = '{"data":{"statuses":[' +
        '{"idstr":"1","text":"Hello<br>HarmonyOS","user":{"idstr":"u1","screen_name":"Alice"}},' +
        '{"idstr":"1","text":"duplicate","user":{"idstr":"u1","screen_name":"Alice"}}]}}';
      const page: PageResult<WeiboPost> = WeiboParser.parsePosts(source, 1);
      expect(page.items.length).assertEqual(1);
      expect(page.items[0].text).assertEqual('Hello\nHarmonyOS');
      expect(page.items[0].user.name).assertEqual('Alice');
    });

    it('parses_session_config', 0, () => {
      const info: SessionInfo = WeiboParser.parseSession('{"login":true,"uid":"42"}');
      expect(info.loggedIn).assertTrue();
      expect(info.userId).assertEqual('42');
    });

    it('parses_hotflow_comment_data', 0, () => {
      const source: string = '{"data":{"data":[{"idstr":"c1","text":"Nice",' +
        '"user":{"idstr":"u2","screen_name":"Bob"}}],"max_id":7}}';
      expect(WeiboParser.parseComments(source).items[0].user.name).assertEqual('Bob');
      expect(WeiboParser.parseComments(source).nextCursor).assertEqual('7');
    });
  });
}
