import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ApiFailureKind, Result } from '../model/WeiboModels';
import { WeiboSession } from './WeiboSession';

const DOMAIN: number = 0x0000;
const TAG: string = 'WeiboHttp';

interface ApiErrorBody {
  ok?: number;
  msg?: string;
  message?: string;
}

export class WeiboHttpClient {
  private requestSequence: number = 0;

  async get(url: string): Promise<Result<string>> {
    return this.request(url, http.RequestMethod.GET, '');
  }

  async post(url: string, body: string): Promise<Result<string>> {
    return this.request(url, http.RequestMethod.POST, body);
  }

  private async request(url: string, method: http.RequestMethod, body: string): Promise<Result<string>> {
    const requestId: number = ++this.requestSequence;
    const request: http.HttpRequest = http.createHttp();
    const cookie: string = await WeiboSession.cookieFor(url);
    const csrf: string = await WeiboSession.csrfToken();
    const endpoint: string = this.safeEndpoint(url);
    const options: http.HttpRequestOptions = this.options(method, body, cookie, csrf, url);
    hilog.info(DOMAIN, TAG, 'request start: id=%{public}d method=%{public}s endpoint=%{public}s cookie=%{public}s csrf=%{public}s',
      requestId, method === http.RequestMethod.POST ? 'POST' : 'GET', endpoint,
      cookie.length > 0 ? 'yes' : 'no', csrf.length > 0 ? 'yes' : 'no');
    try {
      const response: http.HttpResponse = await request.request(url, options);
      const content: string = response.result as string;
      hilog.info(DOMAIN, TAG, 'request end: id=%{public}d status=%{public}d bytes=%{public}d',
        requestId, response.responseCode, content.length);
      if (response.responseCode === 401) {
        return Result.fail<string>('', true, ApiFailureKind.AUTH_EXPIRED, response.responseCode);
      }
      if (response.responseCode === 403) {
        const forbiddenFailure: ApiFailureKind = this.apiFailure(content);
        const failureKind: ApiFailureKind = forbiddenFailure === ApiFailureKind.NONE ?
          ApiFailureKind.HTTP_STATUS : forbiddenFailure;
        return Result.fail<string>('', failureKind === ApiFailureKind.AUTH_EXPIRED,
          failureKind, response.responseCode);
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return Result.fail<string>('', false, ApiFailureKind.HTTP_STATUS, response.responseCode);
      }
      const apiFailure: ApiFailureKind = this.apiFailure(content);
      if (apiFailure !== ApiFailureKind.NONE) {
        return Result.fail<string>('', apiFailure === ApiFailureKind.AUTH_EXPIRED, apiFailure, response.responseCode);
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
    url: string): http.HttpRequestOptions {
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
        'Referer': this.referer(url),
        'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS; Mobile) AppleWebKit/537.36 Mobile Safari/537.36',
        'MWeibo-Pwa': '1',
        'X-Requested-With': 'XMLHttpRequest',
        'X-XSRF-TOKEN': csrf
      }
    };
    if (body.length > 0) {
      options.extraData = body;
    }
    return options;
  }

  private apiFailure(content: string): ApiFailureKind {
    try {
      const body: ApiErrorBody = JSON.parse(content) as ApiErrorBody;
      if (body.ok !== 0) {
        return ApiFailureKind.NONE;
      }
      const message: string = body.msg ?? body.message ?? '';
      if (message.includes('登录') || message.toLowerCase().includes('login')) {
        return ApiFailureKind.AUTH_EXPIRED;
      }
      hilog.warn(DOMAIN, TAG, 'api rejected request');
      return ApiFailureKind.API_REJECTED;
    } catch (error) {
      return ApiFailureKind.NONE;
    }
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
