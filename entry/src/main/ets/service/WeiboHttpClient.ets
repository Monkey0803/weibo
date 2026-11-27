import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ApiFailureKind, Result } from '../model/WeiboModels';
import { WeiboRequestPolicy } from './WeiboRequestPolicy';
import { WeiboSession } from './WeiboSession';

const DOMAIN: number = 0x0000;
const TAG: string = 'WeiboHttp';

interface ApiErrorBody {
  ok?: number;
  msg?: string;
  message?: string;
}

class ApiFailureInfo {
  readonly kind: ApiFailureKind;
  readonly message: string;

  constructor(kind: ApiFailureKind = ApiFailureKind.NONE, message: string = '') {
    this.kind = kind;
    this.message = message;
  }
}

class SessionCredentials {
  readonly cookie: string;
  readonly csrf: string;

  constructor(cookie: string, csrf: string) {
    this.cookie = cookie;
    this.csrf = csrf;
  }
}

export class WeiboHttpClient {
  private requestSequence: number = 0;

  async get(url: string, refererOverride: string = ''): Promise<Result<string>> {
    return this.request(url, http.RequestMethod.GET, '', refererOverride);
  }

  async post(url: string, body: string, refererOverride: string = ''): Promise<Result<string>> {
    return this.request(url, http.RequestMethod.POST, body, refererOverride);
  }

  private async request(url: string, method: http.RequestMethod, body: string,
    refererOverride: string): Promise<Result<string>> {
    const requestId: number = ++this.requestSequence;
    const request: http.HttpRequest = http.createHttp();
    const credentials: SessionCredentials = await this.credentials(url, method);
    const requestBody: string = method === http.RequestMethod.POST && url.startsWith(WeiboSession.MOBILE_ORIGIN) ?
      WeiboRequestPolicy.withCsrf(body, credentials.csrf) : body;
    const endpoint: string = this.safeEndpoint(url);
    const options: http.HttpRequestOptions = this.options(method, requestBody, credentials.cookie,
      credentials.csrf, url, refererOverride);
    hilog.info(DOMAIN, TAG, 'request start: id=%{public}d method=%{public}s endpoint=%{public}s cookie=%{public}s csrf=%{public}s',
      requestId, method === http.RequestMethod.POST ? 'POST' : 'GET', endpoint,
      credentials.cookie.length > 0 ? 'yes' : 'no', credentials.csrf.length > 0 ? 'yes' : 'no');
    try {
      const response: http.HttpResponse = await request.request(url, options);
      const content: string = response.result as string;
      hilog.info(DOMAIN, TAG, 'request end: id=%{public}d status=%{public}d bytes=%{public}d',
        requestId, response.responseCode, content.length);
      if (response.responseCode === 401) {
        return Result.fail<string>('', true, ApiFailureKind.AUTH_EXPIRED, response.responseCode);
      }
      if (response.responseCode === 403) {
        const forbidden: ApiFailureInfo = this.apiFailure(content);
        const failureKind: ApiFailureKind = forbidden.kind === ApiFailureKind.NONE ?
          ApiFailureKind.HTTP_STATUS : forbidden.kind;
        return Result.fail<string>(forbidden.message, failureKind === ApiFailureKind.AUTH_EXPIRED,
          failureKind, response.responseCode);
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return Result.fail<string>('', false, ApiFailureKind.HTTP_STATUS, response.responseCode);
      }
      const apiFailure: ApiFailureInfo = this.apiFailure(content);
      if (apiFailure.kind !== ApiFailureKind.NONE) {
        return Result.fail<string>(apiFailure.message, apiFailure.kind === ApiFailureKind.AUTH_EXPIRED,
          apiFailure.kind, response.responseCode);
      }
      return Result.ok<string>(content);
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'request exception: id=%{public}d code=%{public}d', requestId, businessError.code);
      return Result.fail<string>('', false, ApiFailureKind.NETWORK);
    } finally {
      request.destroy();
    }
  }

  private options(method: http.RequestMethod, body: string, cookie: string, csrf: string,
    url: string, refererOverride: string): http.HttpRequestOptions {
    const options: http.HttpRequestOptions = {
      method: method,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 20000,
      usingCache: false,
      header: {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Cookie': cookie,
        'Origin': WeiboRequestPolicy.origin(url),
        'Referer': refererOverride.length > 0 ? refererOverride : this.referer(url),
        'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS; Mobile) AppleWebKit/537.36 Mobile Safari/537.36',
        'MWeibo-Pwa': '1',
        'X-Requested-With': 'XMLHttpRequest',
        'X-XSRF-TOKEN': csrf,
        'X-CSRF-TOKEN': csrf
      }
    };
    if (body.length > 0) {
      options.extraData = body;
    }
    return options;
  }

  private async credentials(url: string, method: http.RequestMethod): Promise<SessionCredentials> {
    let cookie: string = await WeiboSession.cookieFor(url);
    let csrf: string = await WeiboSession.csrfToken();
    if (method !== http.RequestMethod.POST || !url.startsWith(WeiboSession.MOBILE_ORIGIN)) {
      return new SessionCredentials(cookie, csrf);
    }
    const rawToken: string = await this.refreshCsrfCookie(cookie);
    if (rawToken.length === 0) {
      return new SessionCredentials(cookie, csrf);
    }
    cookie = WeiboRequestPolicy.replaceCookie(cookie, 'XSRF-TOKEN', rawToken);
    try {
      csrf = decodeURIComponent(rawToken);
    } catch (error) {
      csrf = rawToken;
    }
    await WeiboSession.storeCsrfCookie(rawToken);
    return new SessionCredentials(cookie, csrf);
  }

  private async refreshCsrfCookie(cookie: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 20000,
      usingCache: false,
      header: {
        'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
        'Cookie': cookie,
        'Referer': WeiboSession.MOBILE_ORIGIN + '/',
        'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS; Mobile) AppleWebKit/537.36 Mobile Safari/537.36'
      }
    };
    try {
      const response: http.HttpResponse = await request.request(
        WeiboSession.MOBILE_ORIGIN + '/api/config', options);
      const content: string = response.result as string;
      const responseToken: string = WeiboRequestPolicy.cookieValue(response.cookies, 'XSRF-TOKEN');
      const token: string = responseToken.length > 0 ? responseToken :
        WeiboRequestPolicy.csrfTokenFromConfig(content);
      hilog.info(DOMAIN, TAG, 'csrf refresh: status=%{public}d token=%{public}s',
        response.responseCode, token.length > 0 ? 'yes' : 'no');
      return token;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'csrf refresh failed');
      return '';
    } finally {
      request.destroy();
    }
  }

  private apiFailure(content: string): ApiFailureInfo {
    try {
      const body: ApiErrorBody = JSON.parse(content) as ApiErrorBody;
      if (body.ok !== 0) {
        return new ApiFailureInfo();
      }
      const message: string = this.safeMessage(body.msg ?? body.message ?? '');
      if (message.includes('登录') || message.toLowerCase().includes('login')) {
        return new ApiFailureInfo(ApiFailureKind.AUTH_EXPIRED, message);
      }
      hilog.warn(DOMAIN, TAG, 'api rejected request');
      return new ApiFailureInfo(ApiFailureKind.API_REJECTED, message);
    } catch (error) {
      return new ApiFailureInfo();
    }
  }

  private safeMessage(message: string): string {
    const trimmed: string = message.trim();
    return trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed;
  }

  private referer(url: string): string {
    if (url.startsWith(WeiboSession.DESKTOP_ORIGIN)) {
      return WeiboSession.DESKTOP_ORIGIN + '/';
    }
    return WeiboSession.MOBILE_ORIGIN + '/';
  }

  private safeEndpoint(url: string): string {
    const queryIndex: number = url.indexOf('?');
    return queryIndex >= 0 ? url.substring(0, queryIndex) : url;
  }
}

export const weiboHttpClient: WeiboHttpClient = new WeiboHttpClient();
