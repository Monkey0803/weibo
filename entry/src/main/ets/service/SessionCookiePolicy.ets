export class SessionCookiePolicy {
  static isWeiboDomain(domain: string): boolean {
    const normalized: string = domain.toLowerCase();
    return normalized === 'weibo.cn' || normalized.endsWith('.weibo.cn') ||
      normalized === 'weibo.com' || normalized.endsWith('.weibo.com');
  }

  static isSessionCookieName(name: string): boolean {
    return name === 'SUB' || name === 'SUBP' || name === 'SSOLoginState' || name === 'SCF' || name === 'ALF';
  }
}
