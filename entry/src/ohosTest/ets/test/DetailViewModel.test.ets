import { describe, it, expect } from '@ohos/hypium';
import {
  ApiFailureKind,
  CommentPageResult,
  LoadState,
  Result,
  WeiboLiveState,
  WeiboMediaKind,
  WeiboPost
} from '../../../main/ets/model/WeiboModels';
import {
  commentsStateAfterExhaustion,
  isCommentPageExhausted,
  mergePostDetail,
  prepareDetailFallback
} from '../../../main/ets/viewmodel/DetailViewModel';

export default function detailViewModelTest() {
  describe('DetailViewModel', () => {
    it('keeps_live_semantics_when_detail_only_contains_stream_video', 0, () => {
      const initial: WeiboPost = new WeiboPost();
      initial.media.kind = WeiboMediaKind.LIVE;
      initial.media.pageUrl = 'https://weibo.com/l/wblive/p/show/123';
      initial.media.pageTitle = '发布会直播';
      initial.media.liveState = WeiboLiveState.ACTIVE;

      const detail: WeiboPost = new WeiboPost();
      detail.media.kind = WeiboMediaKind.VIDEO;
      detail.media.videoUrl = 'https://example.com/live.m3u8';

      const merged: WeiboPost = mergePostDetail(detail, initial);
      expect(merged.media.kind).assertEqual(WeiboMediaKind.LIVE);
      expect(merged.media.pageUrl).assertEqual(initial.media.pageUrl);
      expect(merged.media.pageTitle).assertEqual(initial.media.pageTitle);
      expect(merged.media.liveState).assertEqual(WeiboLiveState.ACTIVE);
    });

    it('marks_long_initial_post_when_detail_request_fails', 0, () => {
      const initial: WeiboPost = new WeiboPost();
      initial.isLongText = true;
      const fallback: WeiboPost = prepareDetailFallback(initial);
      expect(fallback.fullTextUnavailable).assertTrue();

      const shortPost: WeiboPost = new WeiboPost();
      expect(prepareDetailFallback(shortPost).fullTextUnavailable).assertFalse();
    });

    it('clears_stale_full_text_error_after_detail_succeeds', 0, () => {
      const initial: WeiboPost = new WeiboPost();
      initial.fullTextUnavailable = true;
      const detail: WeiboPost = new WeiboPost();
      detail.text = 'Full text';
      expect(mergePostDetail(detail, initial).fullTextUnavailable).assertFalse();
    });

    it('treats_no_data_from_comment_pagination_as_normal_completion', 0, () => {
      const noData: Result<CommentPageResult> = Result.fail<CommentPageResult>(
        '暂无数据', false, ApiFailureKind.API_REJECTED);
      expect(isCommentPageExhausted(noData)).assertTrue();
      expect(commentsStateAfterExhaustion(1)).assertEqual(LoadState.READY);
      expect(commentsStateAfterExhaustion(0)).assertEqual(LoadState.EMPTY);
    });

    it('keeps_real_comment_failures_visible', 0, () => {
      const network: Result<CommentPageResult> = Result.fail<CommentPageResult>(
        '暂无数据', false, ApiFailureKind.NETWORK);
      const rejected: Result<CommentPageResult> = Result.fail<CommentPageResult>(
        '请求过于频繁', false, ApiFailureKind.API_REJECTED);
      const permission: Result<CommentPageResult> = Result.fail<CommentPageResult>(
        '没有数据访问权限', false, ApiFailureKind.API_REJECTED);
      const forbidden: Result<CommentPageResult> = Result.fail<CommentPageResult>(
        '暂无数据', true, ApiFailureKind.API_REJECTED, 403);
      expect(isCommentPageExhausted(network)).assertFalse();
      expect(isCommentPageExhausted(rejected)).assertFalse();
      expect(isCommentPageExhausted(permission)).assertFalse();
      expect(isCommentPageExhausted(forbidden)).assertFalse();
    });
  });
}
