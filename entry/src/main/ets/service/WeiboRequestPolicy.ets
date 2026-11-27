export class WeiboWriteRequest {
  readonly path: string;
  readonly body: string;
  readonly referer: string;

  constructor(path: string, body: string, referer: string) {
    this.path = path;
    this.body = body;
    this.referer = referer;
  }
}

export class WeiboRequestPolicy {
  static readonly XSRF_HEADER: string = 'X-XSRF-TOKEN';
  static readonly CSRF_HEADER: string = 'X-CSRF-TOKEN';
  static readonly PAGE_SIZE: number = 20;
  private static readonly MOBILE_ORIGIN: string = 'https://m.weibo.cn';

  static followingFeedPath(cursor: string): string {
    return cursor.length > 0 ? '/feed/friends?max_id=' + encodeURIComponent(cursor) : '/feed/friends';
  }

  static followingFeedReferer(): string {
    return WeiboRequestPolicy.MOBILE_ORIGIN + '/';
  }

  static statusDetailPath(postId: string): string {
    return '/api/statuses/show?id=' + encodeURIComponent(postId);
  }

  static longTextPath(postId: string): string {
    return '/statuses/extend?id=' + encodeURIComponent(postId);
  }

  static publish(text: string): WeiboWriteRequest {
    return new WeiboWriteRequest('/api/statuses/update',
      'content=' + encodeURIComponent(text), WeiboRequestPolicy.MOBILE_ORIGIN + '/compose/');
  }

  static comment(postId: string, text: string): WeiboWriteRequest {
    return new WeiboWriteRequest('/api/comments/create',
      'mid=' + encodeURIComponent(postId) + '&content=' + encodeURIComponent(text),
      WeiboRequestPolicy.statusReferer(postId));
  }

  static like(postId: string, liked: boolean): WeiboWriteRequest {
    const path: string = liked ? '/api/attitudes/destroy' : '/api/attitudes/create';
    const attitude: string = liked ? '' : '&attitude=heart';
    return new WeiboWriteRequest(path, 'id=' + encodeURIComponent(postId) + attitude,
      WeiboRequestPolicy.statusReferer(postId));
  }

  static repost(postId: string, mid: string, content: string): WeiboWriteRequest {
    const contentId: string = mid.length > 0 ? mid : postId;
    const repostContent: string = content.length > 0 ? content : '转发微博';
    return new WeiboWriteRequest('/api/statuses/repost',
      'id=' + encodeURIComponent(contentId) + '&mid=' + encodeURIComponent(contentId) +
        '&content=' + encodeURIComponent(repostContent),
      WeiboRequestPolicy.statusReferer(contentId));
  }

  static deletePost(postId: string, mid: string): WeiboWriteRequest {
    const contentId: string = mid.length > 0 ? mid : postId;
    return new WeiboWriteRequest('/profile/delMyblog',
      'mid=' + encodeURIComponent(contentId), WeiboRequestPolicy.statusReferer(contentId));
  }

  static statusReferer(postId: string): string {
    return WeiboRequestPolicy.MOBILE_ORIGIN + '/status/' + encodeURIComponent(postId);
  }

  static origin(url: string): string {
    const schemeIndex: number = url.indexOf('://');
    if (schemeIndex < 0) {
      return '';
    }
    const originEnd: number = url.indexOf('/', schemeIndex + 3);
    return originEnd >= 0 ? url.substring(0, originEnd) : url;
  }

  static cookieValue(source: string, name: string): string {
    const marker: string = name + '=';
    const start: number = source.indexOf(marker);
    if (start < 0) {
      return '';
    }
    const valueStart: number = start + marker.length;
    let valueEnd: number = source.indexOf(';', valueStart);
    const lineEnd: number = source.indexOf('\n', valueStart);
    if (valueEnd < 0 || lineEnd >= 0 && lineEnd < valueEnd) {
      valueEnd = lineEnd;
    }
    return valueEnd >= 0 ? source.substring(valueStart, valueEnd).trim() : source.substring(valueStart).trim();
  }

  static mergeCookie(source: string, name: string, value: string): string {
    if (value.length === 0 || WeiboRequestPolicy.cookieValue(source, name).length > 0) {
      return source;
    }
    const separator: string = source.trim().length > 0 ? '; ' : '';
    return source + separator + name + '=' + value;
  }

  static replaceCookie(source: string, name: string, value: string): string {
    if (value.length === 0) {
      return source;
    }
    const marker: string = name + '=';
    const retained: string[] = source.split(';').map((pair: string) => pair.trim())
      .filter((pair: string) => pair.length > 0 && !pair.startsWith(marker));
    retained.push(marker + value);
    return retained.join('; ');
  }

  static csrfTokenFromConfig(content: string): string {
    try {
      const root: Record<string, Object> = JSON.parse(content) as Record<string, Object>;
      const data: Record<string, Object> = root['data'] as Record<string, Object>;
      const token: Object = data['st'];
      return typeof token === 'string' ? token : '';
    } catch (error) {
      return '';
    }
  }

  static withCsrf(body: string, token: string): string {
    if (token.length === 0 || body.split('&').some((field: string) => field.startsWith('st='))) {
      return body;
    }
    const separator: string = body.length > 0 ? '&' : '';
    return body + separator + 'st=' + encodeURIComponent(token);
  }
}
