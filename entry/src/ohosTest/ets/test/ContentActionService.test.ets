import { describe, it, expect } from '@ohos/hypium';
import { WeiboMediaKind, WeiboPost } from '../../../main/ets/model/WeiboModels';
import { ContentActionService } from '../../../main/ets/service/ContentActionService';

export default function contentActionServiceTest() {
  describe('ContentActionService', () => {
    const service: ContentActionService = new ContentActionService();

    it('uses_mid_then_falls_back_to_id_for_post_url', 0, () => {
      const post: WeiboPost = new WeiboPost();
      post.id = '123';
      post.mid = 'Ab/C';
      expect(service.postUrl(post)).assertEqual('https://m.weibo.cn/detail/Ab%2FC');
      post.mid = '';
      expect(service.postUrl(post)).assertEqual('https://m.weibo.cn/detail/123');
    });

    it('builds_profile_url_and_empty_fallback', 0, () => {
      expect(service.profileUrl('42')).assertEqual('https://m.weibo.cn/u/42');
      expect(service.profileUrl('')).assertEqual('');
    });

    it('uses_safe_official_live_page_then_falls_back_to_post', 0, () => {
      const post: WeiboPost = new WeiboPost();
      post.id = '123';
      post.media.kind = WeiboMediaKind.LIVE;
      post.media.pageUrl = 'https://weibo.com/l/wblive/p/show/123';
      expect(service.liveUrl(post)).assertEqual('https://weibo.com/l/wblive/p/show/123');
      post.media.pageUrl = 'javascript:alert(1)';
      expect(service.liveUrl(post)).assertEqual('https://m.weibo.cn/detail/123');
      post.media.pageUrl = 'http://weibo.com/l/wblive/p/show/123';
      expect(service.liveUrl(post)).assertEqual('https://m.weibo.cn/detail/123');
      post.media.pageUrl = 'https://weibo.com.evil.example/l/wblive/p/show/123';
      expect(service.liveUrl(post)).assertEqual('https://m.weibo.cn/detail/123');
      post.media.pageUrl = 'https://weibo.com@evil.example/l/wblive/p/show/123';
      expect(service.liveUrl(post)).assertEqual('https://m.weibo.cn/detail/123');
    });

    it('truncates_post_summary_and_keeps_web_link', 0, () => {
      const post: WeiboPost = new WeiboPost();
      post.mid = '456';
      post.user.name = '作者';
      post.text = '一'.repeat(140);
      const shareText: string = service.postShareText(post);
      expect(shareText.indexOf('…\nhttps://m.weibo.cn/detail/456') > 0).assertTrue();
      expect(shareText.startsWith('作者：')).assertTrue();
    });
  });
}
