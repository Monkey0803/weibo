import {
  ApiFailureKind,
  CommentLoadMode,
  CommentPageResult,
  FeedKind,
  PageResult,
  Result,
  SearchKind,
  SessionInfo,
  SocialTextContent,
  WeiboComment,
  WeiboHotTopic,
  WeiboPost,
  WeiboUser
} from '../model/WeiboModels';
import { WeiboHttpClient, weiboHttpClient } from './WeiboHttpClient';
import { WeiboParser } from './WeiboParser';
import { WeiboSession } from './WeiboSession';
import { WeiboRequestPolicy, WeiboWriteRequest } from './WeiboRequestPolicy';

export class WeiboRepository {
  private readonly client: WeiboHttpClient = weiboHttpClient;
  private static readonly BASIC_COMMENT_CURSOR_PREFIX: string = 'basic:';
  private static readonly HOT_COMMENT_CURSOR_PREFIX: string = 'hot:';

  async session(): Promise<Result<SessionInfo>> {
    await WeiboSession.refresh();
    const response: Result<string> = await this.client.get(WeiboSession.MOBILE_ORIGIN + '/api/config');
    if (!response.success || !response.data) {
      return Result.fail<SessionInfo>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      return Result.ok<SessionInfo>(WeiboParser.parseSession(response.data));
    } catch (error) {
      return Result.fail<SessionInfo>('', false, ApiFailureKind.PARSE);
    }
  }

  async feed(kind: FeedKind, page: number, cursor: string): Promise<Result<PageResult<WeiboPost>>> {
    if (kind === FeedKind.FOLLOWING) {
      const url: string = WeiboSession.MOBILE_ORIGIN + WeiboRequestPolicy.followingFeedPath(cursor);
      const response: Result<string> = await this.client.get(url, WeiboRequestPolicy.followingFeedReferer());
      return this.parseFollowingPostPage(response);
    }
    let url: string = WeiboSession.MOBILE_ORIGIN +
      '/api/container/getIndex?containerid=102803&page=' + page.toString();
    if (cursor.length > 0) {
      url += '&since_id=' + encodeURIComponent(cursor);
    }
    return this.parsePostPage(await this.client.get(url), page);
  }

  async search(keyword: string, page: number,
    kind: SearchKind = SearchKind.COMPREHENSIVE): Promise<Result<PageResult<WeiboPost>>> {
    const container: string = '100103type=' + kind.toString() + '&q=' + encodeURIComponent(keyword);
    const url: string = WeiboSession.MOBILE_ORIGIN + '/api/container/getIndex?containerid=' + container +
      '&page_type=searchall&page=' + page.toString();
    return this.parsePostPage(await this.client.get(url), page);
  }

  async postDetail(postId: string): Promise<Result<WeiboPost>> {
    const response: Result<string> = await this.client.get(
      WeiboSession.MOBILE_ORIGIN + WeiboRequestPolicy.statusDetailPath(postId),
      WeiboRequestPolicy.statusReferer(postId));
    if (!response.success || !response.data) {
      return Result.fail<WeiboPost>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      const post: WeiboPost = WeiboParser.parsePost(response.data);
      const embeddedFullText: SocialTextContent =
        WeiboParser.parseEmbeddedLongTextContent(response.data, post.id);
      await this.loadFullText(post, embeddedFullText);
      if (post.repost) {
        const embeddedRepostText: SocialTextContent =
          WeiboParser.parseEmbeddedLongTextContent(response.data, post.repost.id);
        await this.loadFullText(post.repost, embeddedRepostText);
      }
      return Result.ok<WeiboPost>(post);
    } catch (error) {
      return Result.fail<WeiboPost>('', false, ApiFailureKind.PARSE);
    }
  }

  async comments(postId: string, mid: string, cursor: string): Promise<Result<CommentPageResult>> {
    const contentId: string = mid.length > 0 ? mid : postId;
    if (cursor.startsWith(WeiboRepository.BASIC_COMMENT_CURSOR_PREFIX)) {
      const pageText: string = cursor.substring(WeiboRepository.BASIC_COMMENT_CURSOR_PREFIX.length);
      const page: number = Number.parseInt(pageText);
      return this.basicComments(contentId, Number.isNaN(page) ? 1 : page);
    }
    const hotCursor: string = cursor.startsWith(WeiboRepository.HOT_COMMENT_CURSOR_PREFIX) ?
      cursor.substring(WeiboRepository.HOT_COMMENT_CURSOR_PREFIX.length) : cursor;
    const hot: Result<CommentPageResult> = await this.hotComments(contentId, hotCursor);
    if (hot.success || cursor.length > 0 || hot.failureKind === ApiFailureKind.NETWORK) {
      return hot;
    }
    return this.basicComments(contentId, 1);
  }

  private async hotComments(contentId: string, cursor: string): Promise<Result<CommentPageResult>> {
    let url: string = WeiboSession.MOBILE_ORIGIN + '/comments/hotflow?id=' + encodeURIComponent(contentId) +
      '&mid=' + encodeURIComponent(contentId) + '&max_id_type=0';
    if (cursor.length > 0) {
      url += '&max_id=' + encodeURIComponent(cursor);
    }
    const referer: string = WeiboRequestPolicy.statusReferer(contentId);
    const response: Result<string> = await this.client.get(url, referer);
    if (!response.success || !response.data) {
      return Result.fail<CommentPageResult>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      const page: PageResult<WeiboComment> = WeiboParser.parseComments(response.data);
      const nextCursor: string = page.hasMore ? WeiboRepository.HOT_COMMENT_CURSOR_PREFIX + page.nextCursor : '';
      const normalized: PageResult<WeiboComment> = new PageResult<WeiboComment>(page.items, nextCursor, page.hasMore);
      return Result.ok<CommentPageResult>(new CommentPageResult(normalized, CommentLoadMode.HOT));
    } catch (error) {
      return Result.fail<CommentPageResult>('', false, ApiFailureKind.PARSE);
    }
  }

  private async basicComments(contentId: string, pageNumber: number): Promise<Result<CommentPageResult>> {
    const url: string = WeiboSession.MOBILE_ORIGIN + '/api/comments/show?id=' + encodeURIComponent(contentId) +
      '&page=' + pageNumber.toString() + '&count=' + WeiboRequestPolicy.PAGE_SIZE.toString();
    const referer: string = WeiboRequestPolicy.statusReferer(contentId);
    const response: Result<string> = await this.client.get(url, referer);
    if (!response.success || !response.data) {
      return Result.fail<CommentPageResult>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      const page: PageResult<WeiboComment> = WeiboParser.parseBasicComments(response.data, pageNumber);
      const nextCursor: string = page.hasMore ? WeiboRepository.BASIC_COMMENT_CURSOR_PREFIX + page.nextCursor : '';
      const normalized: PageResult<WeiboComment> = new PageResult<WeiboComment>(page.items, nextCursor, page.hasMore);
      return Result.ok<CommentPageResult>(new CommentPageResult(normalized, CommentLoadMode.BASIC));
    } catch (error) {
      return Result.fail<CommentPageResult>('', false, ApiFailureKind.PARSE);
    }
  }

  async profile(userId: string): Promise<Result<WeiboUser>> {
    const url: string = WeiboSession.MOBILE_ORIGIN + '/api/container/getIndex?type=uid&value=' +
      encodeURIComponent(userId) + '&containerid=100505' + encodeURIComponent(userId);
    const response: Result<string> = await this.client.get(url);
    if (!response.success || !response.data) {
      return Result.fail<WeiboUser>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      const user: WeiboUser = WeiboParser.parseUser(response.data);
      const detail: Result<string> = await this.client.get(WeiboSession.DESKTOP_ORIGIN +
        '/ajax/profile/detail?uid=' + encodeURIComponent(userId));
      if (detail.success && detail.data) {
        WeiboParser.mergeUserDetail(user, detail.data);
      }
      return Result.ok<WeiboUser>(user);
    } catch (error) {
      return Result.fail<WeiboUser>('', false, ApiFailureKind.PARSE);
    }
  }

  async userPosts(userId: string, page: number): Promise<Result<PageResult<WeiboPost>>> {
    const url: string = WeiboSession.MOBILE_ORIGIN + '/api/container/getIndex?type=uid&value=' +
      encodeURIComponent(userId) + '&containerid=107603' + encodeURIComponent(userId) +
      '&page=' + page.toString();
    return this.parsePostPage(await this.client.get(url), page);
  }

  async like(postId: string, liked: boolean): Promise<Result<boolean>> {
    return this.mutate(WeiboRequestPolicy.like(postId, liked));
  }

  async createComment(postId: string, text: string): Promise<Result<boolean>> {
    return this.mutate(WeiboRequestPolicy.comment(postId, text));
  }

  async createCommentDetail(postId: string, text: string): Promise<Result<WeiboComment>> {
    const request: WeiboWriteRequest = WeiboRequestPolicy.comment(postId, text);
    const response: Result<string> = await this.client.post(
      WeiboSession.MOBILE_ORIGIN + request.path, request.body, request.referer);
    if (!response.success || !response.data) {
      return Result.fail<WeiboComment>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      const comment: WeiboComment = WeiboParser.parseCreatedComment(response.data);
      return comment.id.length > 0 ? Result.ok<WeiboComment>(comment) :
        Result.fail<WeiboComment>('', false, ApiFailureKind.PARSE);
    } catch (error) {
      return Result.fail<WeiboComment>('', false, ApiFailureKind.PARSE);
    }
  }

  async commentReplies(postId: string, commentId: string,
    cursor: string): Promise<Result<PageResult<WeiboComment>>> {
    let url: string = WeiboSession.MOBILE_ORIGIN + '/comments/hotFlowChild?cid=' +
      encodeURIComponent(commentId) + '&max_id_type=0';
    if (cursor.length > 0) {
      url += '&max_id=' + encodeURIComponent(cursor);
    }
    const referer: string = WeiboRequestPolicy.statusReferer(postId) +
      '?cid=' + encodeURIComponent(commentId);
    const response: Result<string> = await this.client.get(url, referer);
    if (!response.success || !response.data) {
      return Result.fail<PageResult<WeiboComment>>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      return Result.ok<PageResult<WeiboComment>>(WeiboParser.parseCommentReplies(response.data));
    } catch (error) {
      return Result.fail<PageResult<WeiboComment>>('', false, ApiFailureKind.PARSE);
    }
  }

  async hotTopics(): Promise<Result<WeiboHotTopic[]>> {
    const response: Result<string> = await this.client.get(
      WeiboSession.DESKTOP_ORIGIN + '/ajax/side/hotSearch');
    if (!response.success || !response.data) {
      return Result.fail<WeiboHotTopic[]>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      return Result.ok<WeiboHotTopic[]>(WeiboParser.parseHotTopics(response.data));
    } catch (error) {
      return Result.fail<WeiboHotTopic[]>('', false, ApiFailureKind.PARSE);
    }
  }

  async socialUsers(userId: string, followers: boolean, page: number): Promise<Result<PageResult<WeiboUser>>> {
    const url: string = followers ? WeiboSession.DESKTOP_ORIGIN + '/ajax/friendships/friends?uid=' +
      encodeURIComponent(userId) + '&page=' + page.toString() + '&relate=fans' :
      WeiboSession.MOBILE_ORIGIN + '/api/friendships/friends?uid=' + encodeURIComponent(userId) +
        '&page=' + page.toString() + '&count=20';
    const response: Result<string> = await this.client.get(url);
    if (!response.success || !response.data) {
      return Result.fail<PageResult<WeiboUser>>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      return Result.ok<PageResult<WeiboUser>>(WeiboParser.parseUsers(response.data, page));
    } catch (error) {
      return Result.fail<PageResult<WeiboUser>>('', false, ApiFailureKind.PARSE);
    }
  }

  async reposts(postId: string, page: number): Promise<Result<PageResult<WeiboPost>>> {
    const url: string = WeiboSession.MOBILE_ORIGIN + '/api/statuses/repostTimeline?id=' +
      encodeURIComponent(postId) + '&page=' + page.toString() + '&count=20';
    return this.parsePostPage(await this.client.get(url), page);
  }

  async follow(userId: string, following: boolean): Promise<Result<boolean>> {
    const path: string = following ? '/ajax/friendships/destory' : '/ajax/friendships/create';
    const key: string = following ? 'uid=' : 'friend_uid=';
    return this.mutateAt(WeiboSession.DESKTOP_ORIGIN, path, key + encodeURIComponent(userId));
  }

  async favorite(postId: string, favorited: boolean): Promise<Result<boolean>> {
    const path: string = favorited ? '/ajax/statuses/destoryFavorites' : '/ajax/statuses/createFavorites';
    return this.mutateAt(WeiboSession.DESKTOP_ORIGIN, path, 'id=' + encodeURIComponent(postId));
  }

  async publish(text: string): Promise<Result<WeiboPost>> {
    const request: WeiboWriteRequest = WeiboRequestPolicy.publish(text);
    const response: Result<string> = await this.client.post(
      WeiboSession.MOBILE_ORIGIN + request.path, request.body, request.referer);
    if (!response.success || !response.data) {
      return Result.fail<WeiboPost>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      const post: WeiboPost = WeiboParser.parseCreatedPost(response.data);
      return post.id.length > 0 ? Result.ok<WeiboPost>(post) :
        Result.fail<WeiboPost>('', false, ApiFailureKind.PARSE);
    } catch (error) {
      return Result.fail<WeiboPost>('', false, ApiFailureKind.PARSE);
    }
  }

  async deletePost(postId: string, mid: string): Promise<Result<boolean>> {
    return this.mutate(WeiboRequestPolicy.deletePost(postId, mid));
  }

  async repost(postId: string, mid: string, content: string): Promise<Result<boolean>> {
    return this.mutate(WeiboRequestPolicy.repost(postId, mid, content));
  }

  private async loadFullText(post: WeiboPost, embeddedFallback: SocialTextContent): Promise<void> {
    if (!post.isLongText || post.id.length === 0) {
      return;
    }
    const response: Result<string> = await this.client.get(
      WeiboSession.MOBILE_ORIGIN + WeiboRequestPolicy.longTextPath(post.id),
      WeiboRequestPolicy.statusReferer(post.id));
    if (!response.success || !response.data) {
      if (!this.applyFullText(post, embeddedFallback)) {
        post.fullTextUnavailable = true;
      }
      return;
    }
    try {
      const fullText: SocialTextContent = WeiboParser.parseLongTextContent(response.data);
      if (!this.applyFullText(post, fullText) && !this.applyFullText(post, embeddedFallback)) {
        post.fullTextUnavailable = true;
      }
    } catch (error) {
      if (!this.applyFullText(post, embeddedFallback)) {
        post.fullTextUnavailable = true;
      }
    }
  }

  private applyFullText(post: WeiboPost, content: SocialTextContent): boolean {
    if (content.text.length === 0) {
      return false;
    }
    post.text = content.text;
    post.textEntities = content.entities;
    post.fullTextUnavailable = false;
    return true;
  }

  private async mutate(request: WeiboWriteRequest): Promise<Result<boolean>> {
    return this.mutateAt(WeiboSession.MOBILE_ORIGIN, request.path, request.body, request.referer);
  }

  private async mutateAt(origin: string, path: string, body: string,
    referer: string = ''): Promise<Result<boolean>> {
    const response: Result<string> = await this.client.post(origin + path, body, referer);
    if (!response.success || !response.data) {
      return Result.fail<boolean>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      if (WeiboParser.isSuccessfulMutation(response.data)) {
        return Result.ok<boolean>(true);
      }
      return Result.fail<boolean>('', false, ApiFailureKind.API_REJECTED);
    } catch (error) {
      return Result.fail<boolean>('', false, ApiFailureKind.PARSE);
    }
  }

  private parsePostPage(response: Result<string>, page: number): Result<PageResult<WeiboPost>> {
    if (!response.success || !response.data) {
      return Result.fail<PageResult<WeiboPost>>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      return Result.ok<PageResult<WeiboPost>>(WeiboParser.parsePosts(response.data, page));
    } catch (error) {
      return Result.fail<PageResult<WeiboPost>>('', false, ApiFailureKind.PARSE);
    }
  }

  private parseFollowingPostPage(response: Result<string>): Result<PageResult<WeiboPost>> {
    if (!response.success || !response.data) {
      return Result.fail<PageResult<WeiboPost>>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      return Result.ok<PageResult<WeiboPost>>(WeiboParser.parseFollowingPosts(response.data));
    } catch (error) {
      return Result.fail<PageResult<WeiboPost>>('', false, ApiFailureKind.PARSE);
    }
  }
}

export const weiboRepository: WeiboRepository = new WeiboRepository();
