import { describe, it, expect } from '@ohos/hypium';
import { WeiboRequestPolicy, WeiboWriteRequest } from '../../../main/ets/service/WeiboRequestPolicy';

export default function weiboRequestPolicyTest() {
  describe('WeiboRequestPolicy', () => {
    it('builds_following_feed_requests_with_cursor_pagination', 0, () => {
      expect(WeiboRequestPolicy.followingFeedPath('')).assertEqual('/feed/friends');
      const nextPath: string = WeiboRequestPolicy.followingFeedPath('12+34');
      expect(nextPath).assertEqual('/feed/friends?max_id=12%2B34');
      expect(nextPath.includes('friends_timeline')).assertFalse();
      expect(nextPath.includes('since_id')).assertFalse();
      expect(WeiboRequestPolicy.followingFeedReferer()).assertEqual('https://m.weibo.cn/');
    });

    it('builds_status_detail_and_long_text_paths', 0, () => {
      expect(WeiboRequestPolicy.statusDetailPath('12+34'))
        .assertEqual('/api/statuses/show?id=12%2B34');
      expect(WeiboRequestPolicy.longTextPath('12+34'))
        .assertEqual('/statuses/extend?id=12%2B34');
      expect(WeiboRequestPolicy.statusReferer('12+34'))
        .assertEqual('https://m.weibo.cn/status/12%2B34');
    });

    it('builds_publish_request_with_content_field', 0, () => {
      const request: WeiboWriteRequest = WeiboRequestPolicy.publish('Hello HarmonyOS');
      expect(request.path).assertEqual('/api/statuses/update');
      expect(request.body).assertEqual('content=Hello%20HarmonyOS');
      expect(request.body.includes('status=')).assertFalse();
      expect(request.referer).assertEqual('https://m.weibo.cn/compose/');
    });

    it('builds_comment_like_and_unlike_requests', 0, () => {
      const comment: WeiboWriteRequest = WeiboRequestPolicy.comment('123', '评论 & ok');
      expect(comment.body).assertEqual('mid=123&content=%E8%AF%84%E8%AE%BA%20%26%20ok');
      expect(comment.referer).assertEqual('https://m.weibo.cn/status/123');

      const like: WeiboWriteRequest = WeiboRequestPolicy.like('123', false);
      expect(like.path).assertEqual('/api/attitudes/create');
      expect(like.body).assertEqual('id=123&attitude=heart');

      const unlike: WeiboWriteRequest = WeiboRequestPolicy.like('123', true);
      expect(unlike.path).assertEqual('/api/attitudes/destroy');
      expect(unlike.body).assertEqual('id=123');
    });

    it('builds_repost_request_with_mid_fallback', 0, () => {
      const request: WeiboWriteRequest = WeiboRequestPolicy.repost('post-id', '', '');
      expect(request.body).assertEqual('id=post-id&mid=post-id&content=%E8%BD%AC%E5%8F%91%E5%BE%AE%E5%8D%9A');
      expect(request.referer).assertEqual('https://m.weibo.cn/status/post-id');
    });

    it('builds_mobile_delete_request', 0, () => {
      const request: WeiboWriteRequest = WeiboRequestPolicy.deletePost('post-id', 'post-mid');
      expect(request.path).assertEqual('/profile/delMyblog');
      expect(request.body).assertEqual('mid=post-mid');
      expect(request.referer).assertEqual('https://m.weibo.cn/status/post-mid');
      expect(WeiboRequestPolicy.deletePost('post-id', '').body).assertEqual('mid=post-id');
    });

    it('derives_origins_and_exposes_csrf_header_names', 0, () => {
      expect(WeiboRequestPolicy.origin('https://m.weibo.cn/api/statuses/update'))
        .assertEqual('https://m.weibo.cn');
      expect(WeiboRequestPolicy.origin('https://weibo.com/ajax/statuses/setLike'))
        .assertEqual('https://weibo.com');
      expect(WeiboRequestPolicy.XSRF_HEADER).assertEqual('X-XSRF-TOKEN');
      expect(WeiboRequestPolicy.CSRF_HEADER).assertEqual('X-CSRF-TOKEN');
    });

    it('extracts_and_merges_xsrf_cookie', 0, () => {
      const responseCookies: string = 'MLOGIN=1; Path=/\nXSRF-TOKEN=abc%2B123; Path=/; Secure';
      expect(WeiboRequestPolicy.cookieValue(responseCookies, 'XSRF-TOKEN')).assertEqual('abc%2B123');
      expect(WeiboRequestPolicy.mergeCookie('SUB=session', 'XSRF-TOKEN', 'abc%2B123'))
        .assertEqual('SUB=session; XSRF-TOKEN=abc%2B123');
      expect(WeiboRequestPolicy.mergeCookie('SUB=session; XSRF-TOKEN=existing',
        'XSRF-TOKEN', 'replacement')).assertEqual('SUB=session; XSRF-TOKEN=existing');
      expect(WeiboRequestPolicy.replaceCookie('SUB=session; XSRF-TOKEN=existing; MLOGIN=1',
        'XSRF-TOKEN', 'replacement')).assertEqual('SUB=session; MLOGIN=1; XSRF-TOKEN=replacement');
    });

    it('extracts_config_token_and_adds_it_to_form_body', 0, () => {
      const config: string = '{"ok":1,"data":{"uid":"123","st":"token+value"}}';
      expect(WeiboRequestPolicy.csrfTokenFromConfig(config)).assertEqual('token+value');
      expect(WeiboRequestPolicy.csrfTokenFromConfig('{"ok":0}')).assertEqual('');
      expect(WeiboRequestPolicy.withCsrf('content=hello', 'token+value'))
        .assertEqual('content=hello&st=token%2Bvalue');
      expect(WeiboRequestPolicy.withCsrf('content=hello&st=existing', 'replacement'))
        .assertEqual('content=hello&st=existing');
    });
  });
}
