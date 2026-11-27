import { describe, it, expect } from '@ohos/hypium';
import { WeiboParser } from '../../../main/ets/service/WeiboParser';
import { PageResult, SessionInfo, SocialTextContent, SocialTextEntityKind, WeiboComment, WeiboHotTopic,
  WeiboLiveState, WeiboMediaKind, WeiboPost, WeiboUser } from '../../../main/ets/model/WeiboModels';

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

    it('uses_following_feed_cursor_and_stops_without_one', 0, () => {
      const next: PageResult<WeiboPost> = WeiboParser.parseFollowingPosts(
        '{"data":{"statuses":[{"idstr":"2","text":"Following"}],"max_id_str":"9988"}}');
      expect(next.items.length).assertEqual(1);
      expect(next.nextCursor).assertEqual('9988');
      expect(next.hasMore).assertTrue();

      const last: PageResult<WeiboPost> = WeiboParser.parseFollowingPosts(
        '{"data":{"statuses":[{"idstr":"3","text":"Last"}],"max_id":0}}');
      expect(last.items.length).assertEqual(1);
      expect(last.nextCursor).assertEqual('');
      expect(last.hasMore).assertFalse();

      const missing: PageResult<WeiboPost> = WeiboParser.parseFollowingPosts(
        '{"data":{"statuses":[{"idstr":"4","text":"No cursor"}]}}');
      expect(missing.hasMore).assertFalse();
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

    it('parses_basic_comment_pages_and_stops_on_empty_page', 0, () => {
      const first: PageResult<WeiboComment> = WeiboParser.parseBasicComments(
        '{"data":[{"idstr":"c2","text":"Basic","user":{"screen_name":"Carol"}}]}', 1);
      expect(first.items[0].user.name).assertEqual('Carol');
      expect(first.nextCursor).assertEqual('2');
      expect(first.hasMore).assertTrue();
      const empty: PageResult<WeiboComment> = WeiboParser.parseBasicComments('{"data":[]}', 2);
      expect(empty.items.length).assertEqual(0);
      expect(empty.hasMore).assertFalse();
    });

    it('parses_nested_basic_comment_shape', 0, () => {
      const page: PageResult<WeiboComment> = WeiboParser.parseBasicComments(
        '{"data":{"comments":[{"idstr":"c3","text":"Nested"}]}}', 1);
      expect(page.items[0].id).assertEqual('c3');
    });

    it('parses_long_text_response', 0, () => {
      const source: string = '{"data":{"longTextContent":"Full<br>post &amp; details"}}';
      expect(WeiboParser.parseLongText(source)).assertEqual('Full\npost & details');
    });

    it('parses_embedded_long_text_from_status_and_repost', 0, () => {
      const source: string = '{"idstr":"root","isLongText":true,"longText":{' +
        '"longTextContent":"Root<br>#Topic#"},"retweeted_status":{"idstr":"repost",' +
        '"longText":{"longTextContent":"Repost full text"}}}';
      const root: SocialTextContent = WeiboParser.parseEmbeddedLongTextContent(source, 'root');
      expect(root.text).assertEqual('Root\n#Topic#');
      expect(root.entities.length).assertEqual(1);
      expect(root.entities[0].kind).assertEqual(SocialTextEntityKind.TOPIC);
      const repost: SocialTextContent = WeiboParser.parseEmbeddedLongTextContent(source, 'repost');
      expect(repost.text).assertEqual('Repost full text');
      expect(WeiboParser.parseEmbeddedLongTextContent(source, 'missing').text).assertEqual('');
    });

    it('parses_wrapped_post_and_long_text_flag', 0, () => {
      const source: string = '{"data":{"idstr":"9","text":"Short","isLongText":true,' +
        '"user":{"idstr":"u9","screen_name":"Long Author"}}}';
      const post: WeiboPost = WeiboParser.parsePost(source);
      expect(post.id).assertEqual('9');
      expect(post.isLongText).assertTrue();
    });

    it('infers_long_text_from_full_text_anchor', 0, () => {
      const source: string = '{"data":{"idstr":"5369689015584393","text":"正文' +
        '<a href=\\\"/status/5369689015584393\\\">全文</a>","user":{"idstr":"u1"}}}';
      const post: WeiboPost = WeiboParser.parsePost(source);
      expect(post.isLongText).assertTrue();
    });

    it('infers_truncated_text_from_reported_length', 0, () => {
      const source: string = '{"data":{"idstr":"10","text":"短内容","textLength":984,' +
        '"isLongText":false,"user":{"idstr":"u1"}}}';
      const post: WeiboPost = WeiboParser.parsePost(source);
      expect(post.isLongText).assertTrue();
    });

    it('keeps_regular_short_post_non_long_text', 0, () => {
      const source: string = '{"data":{"idstr":"11","text":"普通短微博",' +
        '"user":{"idstr":"u1"}}}';
      const post: WeiboPost = WeiboParser.parsePost(source);
      expect(post.isLongText).assertFalse();
    });

    it('parses_hot_topics', 0, () => {
      const topics: WeiboHotTopic[] = WeiboParser.parseHotTopics(
        '{"data":{"realtime":[{"word":"HarmonyOS","num":123,"icon_desc":"New"}]}}');
      expect(topics.length).assertEqual(1);
      expect(topics[0].word).assertEqual('HarmonyOS');
      expect(topics[0].heat).assertEqual(123);
    });

    it('parses_desktop_social_users_and_profile_fields', 0, () => {
      const page: PageResult<WeiboUser> = WeiboParser.parseUsers(
        '{"ok":1,"users":[{"idstr":"u1","screen_name":"Alice","avatar_hd":"https://example.com/a.jpg",' +
          '"description":"关注 #鸿蒙# @Bob https://example.com/profile。",' +
          '"following":true,"follow_me":true,"location":"Shanghai"}]}', 1);
      expect(page.items.length).assertEqual(1);
      expect(page.items[0].id).assertEqual('u1');
      expect(page.items[0].name).assertEqual('Alice');
      expect(page.items[0].avatarUrl).assertEqual('https://example.com/a.jpg');
      expect(page.items[0].description).assertEqual('关注 #鸿蒙# @Bob https://example.com/profile。');
      expect(page.items[0].descriptionEntities.length).assertEqual(3);
      expect(page.items[0].following).assertTrue();
      expect(page.items[0].followedBy).assertTrue();
      expect(page.items[0].location).assertEqual('Shanghai');
      expect(page.hasMore).assertFalse();
    });

    it('parses_comment_replies_and_created_comment', 0, () => {
      const replies: PageResult<WeiboComment> = WeiboParser.parseCommentReplies(
        '{"data":{"data":[{"idstr":"r1","text":"Reply","user":{"screen_name":"Bob"}}]}}');
      expect(replies.items[0].text).assertEqual('Reply');
      const created: WeiboComment = WeiboParser.parseCreatedComment(
        '{"data":{"idstr":"c9","text":"Created"}}');
      expect(created.id).assertEqual('c9');
    });

    it('parses_created_post_and_favorite_state', 0, () => {
      const post: WeiboPost = WeiboParser.parseCreatedPost(
        '{"data":{"idstr":"p1","text":"Published","favorited":true}}');
      expect(post.id).assertEqual('p1');
      expect(post.favorited).assertTrue();
    });

    it('classifies_live_media_without_treating_it_as_regular_video', 0, () => {
      const post: WeiboPost = WeiboParser.parsePost('{"idstr":"live-1","text":"Event",' +
        '"page_info":{"type":"video","page_url":"https://weibo.com/l/wblive/p/show/123",' +
        '"page_title":"Launch event","page_pic":{"url":"https://example.com/poster.jpg"},' +
        '"media_info":{"stream_url_hd":"https://example.com/live.m3u8","is_living":true}}}');
      expect(post.media.kind).assertEqual(WeiboMediaKind.LIVE);
      expect(post.media.liveState).assertEqual(WeiboLiveState.ACTIVE);
      expect(post.media.pageUrl).assertEqual('https://weibo.com/l/wblive/p/show/123');
      expect(post.media.pageTitle).assertEqual('Launch event');
      expect(post.media.videoPosterUrl).assertEqual('https://example.com/poster.jpg');
    });

    it('keeps_regular_video_and_handles_unknown_or_ended_live_state', 0, () => {
      const video: WeiboPost = WeiboParser.parsePost('{"idstr":"video-1","page_info":{"type":"video",' +
        '"page_url":"https://weibo.com/tv/show/123",' +
        '"media_info":{"mp4_hd_mp4":"https://example.com/video.mp4"}}}');
      expect(video.media.kind).assertEqual(WeiboMediaKind.VIDEO);

      const unknown: WeiboPost = WeiboParser.parsePost('{"idstr":"live-2","page_info":{' +
        '"type":"11","object_type":"live","object_id":"1022:abc",' +
        '"page_url":"https://m.weibo.cn/status/live-2",' +
        '"media_info":{}}}');
      expect(unknown.media.kind).assertEqual(WeiboMediaKind.LIVE);
      expect(unknown.media.liveState).assertEqual(WeiboLiveState.UNKNOWN);
      expect(unknown.media.pageUrl).assertEqual('https://weibo.com/l/wblive/m/show/1022:abc');

      const ended: WeiboPost = WeiboParser.parsePost('{"idstr":"live-3","page_info":{' +
        '"page_url":"https://weibo.com/l/wblive/p/show/3",' +
        '"media_info":{"live_status":3}}}');
      expect(ended.media.liveState).assertEqual(WeiboLiveState.ENDED);
    });
  });
}
