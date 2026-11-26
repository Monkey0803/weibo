import {
  ApiFailureKind,
  FeedKind,
  PageResult,
  Result,
  SessionInfo,
  WeiboComment,
  WeiboPost,
  WeiboUser
} from '../model/WeiboModels';
import { WeiboHttpClient, weiboHttpClient } from './WeiboHttpClient';
import { WeiboParser } from './WeiboParser';
import { WeiboSession } from './WeiboSession';

export class WeiboRepository {
  private readonly client: WeiboHttpClient = weiboHttpClient;

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
    let url: string = '';
    if (kind === FeedKind.FOLLOWING) {
      url = WeiboSession.MOBILE_ORIGIN + '/api/statuses/friends_timeline?page=' + page.toString() + '&count=20';
    } else {
      url = WeiboSession.MOBILE_ORIGIN + '/api/container/getIndex?containerid=102803&page=' + page.toString();
    }
    return this.parsePostPage(await this.client.get(url), page);
  }

  async search(keyword: string, page: number): Promise<Result<PageResult<WeiboPost>>> {
    const container: string = '100103type=1&q=' + encodeURIComponent(keyword);
    const url: string = WeiboSession.MOBILE_ORIGIN + '/api/container/getIndex?containerid=' + container +
      '&page_type=searchall&page=' + page.toString();
    return this.parsePostPage(await this.client.get(url), page);
  }

  async postDetail(postId: string): Promise<Result<WeiboPost>> {
    const response: Result<string> = await this.client.get(
      WeiboSession.MOBILE_ORIGIN + '/statuses/show?id=' + encodeURIComponent(postId));
    if (!response.success || !response.data) {
      return Result.fail<WeiboPost>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      return Result.ok<WeiboPost>(WeiboParser.parsePost(response.data));
    } catch (error) {
      return Result.fail<WeiboPost>('', false, ApiFailureKind.PARSE);
    }
  }

  async comments(postId: string, mid: string, cursor: string): Promise<Result<PageResult<WeiboComment>>> {
    let url: string = WeiboSession.MOBILE_ORIGIN + '/comments/hotflow?id=' + encodeURIComponent(postId) +
      '&mid=' + encodeURIComponent(mid) + '&max_id_type=0';
    if (cursor.length > 0) {
      url += '&max_id=' + encodeURIComponent(cursor);
    }
    const response: Result<string> = await this.client.get(url);
    if (!response.success || !response.data) {
      return Result.fail<PageResult<WeiboComment>>(response.message, response.authRequired,
        response.failureKind, response.statusCode);
    }
    try {
      return Result.ok<PageResult<WeiboComment>>(WeiboParser.parseComments(response.data));
    } catch (error) {
      return Result.fail<PageResult<WeiboComment>>('', false, ApiFailureKind.PARSE);
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
      return Result.ok<WeiboUser>(WeiboParser.parseUser(response.data));
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
    const path: string = liked ? '/api/attitudes/destroy' : '/api/attitudes/create';
    return this.mutate(path, 'id=' + encodeURIComponent(postId) + '&attitude=heart');
  }

  async createComment(postId: string, text: string): Promise<Result<boolean>> {
    const body: string = 'id=' + encodeURIComponent(postId) + '&content=' + encodeURIComponent(text);
    return this.mutate('/api/comments/create', body);
  }

  private async mutate(path: string, body: string): Promise<Result<boolean>> {
    const response: Result<string> = await this.client.post(WeiboSession.MOBILE_ORIGIN + path, body);
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
}

export const weiboRepository: WeiboRepository = new WeiboRepository();
