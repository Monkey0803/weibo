import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SessionSnapshot } from '../model/WeiboModels';
import { SessionCookiePolicy } from './SessionCookiePolicy';

const DOMAIN: number = 0x0000;
const TAG: string = 'WeiboSession';

export class WeiboSession {
  static readonly MOBILE_ORIGIN: string = 'https://m.weibo.cn';
  static readonly DESKTOP_ORIGIN: string = 'https://weibo.com';
  static readonly LOGIN_URL: string =
    'https://passport.weibo.cn/signin/login?entry=mweibo&r=https%3A%2F%2Fm.weibo.cn%2F';

  static async refresh(): Promise<SessionSnapshot> {
    try {
      await webview.WebCookieManager.saveCookieAsync();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'cookie persistence failed');
    }
    try {
      const cookies: webview.WebHttpCookie[] = await webview.WebCookieManager.fetchAllCookies(false);
      const names: string[] = [];
      const domains: string[] = [];
      let candidate: boolean = false;
      cookies.forEach((cookie: webview.WebHttpCookie) => {
        if (SessionCookiePolicy.isWeiboDomain(cookie.domain)) {
          if (!names.includes(cookie.name)) {
            names.push(cookie.name);
          }
          if (!domains.includes(cookie.domain)) {
            domains.push(cookie.domain);
          }
          if (SessionCookiePolicy.isSessionCookieName(cookie.name)) {
            candidate = true;
          }
        }
      });
      hilog.info(DOMAIN, TAG, 'cookie snapshot: count=%{public}d candidate=%{public}s names=%{public}s domains=%{public}s',
        names.length, candidate ? 'yes' : 'no', names.join(','), domains.join(','));
      return new SessionSnapshot(candidate, names, domains);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'cookie snapshot failed');
      return new SessionSnapshot(false);
    }
  }

  static async cookieFor(url: string): Promise<string> {
    try {
      return await webview.WebCookieManager.fetchCookie(url, false, true);
    } catch (error) {
      try {
        return webview.WebCookieManager.fetchCookieSync(url, false, true);
      } catch (fallbackError) {
        hilog.warn(DOMAIN, TAG, 'cookie lookup failed: host=%{public}s', WeiboSession.safeHost(url));
        return '';
      }
    }
  }

  static async csrfToken(): Promise<string> {
    const mobile: string = await WeiboSession.cookieFor(WeiboSession.MOBILE_ORIGIN + '/');
    const desktop: string = await WeiboSession.cookieFor(WeiboSession.DESKTOP_ORIGIN + '/');
    const pairs: string[] = (mobile + ';' + desktop).split(';');
    for (let index: number = 0; index < pairs.length; index += 1) {
      const pair: string = pairs[index].trim();
      if (pair.startsWith('XSRF-TOKEN=')) {
        try {
          return decodeURIComponent(pair.substring('XSRF-TOKEN='.length));
        } catch (error) {
          return pair.substring('XSRF-TOKEN='.length);
        }
      }
    }
    return '';
  }

  private static safeHost(url: string): string {
    const schemeIndex: number = url.indexOf('://');
    const hostStart: number = schemeIndex >= 0 ? schemeIndex + 3 : 0;
    const pathIndex: number = url.indexOf('/', hostStart);
    return pathIndex >= 0 ? url.substring(hostStart, pathIndex) : url.substring(hostStart);
  }
}
