import { describe, it, expect } from '@ohos/hypium';
import { SessionCookiePolicy } from '../../../main/ets/service/SessionCookiePolicy';
import { ApiFailureKind, Result } from '../../../main/ets/model/WeiboModels';

export default function sessionCookiePolicyTest() {
  describe('SessionCookiePolicy', () => {
    it('matches_weibo_parent_and_subdomains', 0, () => {
      expect(SessionCookiePolicy.isWeiboDomain('.weibo.cn')).assertTrue();
      expect(SessionCookiePolicy.isWeiboDomain('m.weibo.cn')).assertTrue();
      expect(SessionCookiePolicy.isWeiboDomain('passport.weibo.com')).assertTrue();
      expect(SessionCookiePolicy.isWeiboDomain('example.com')).assertFalse();
    });

    it('recognizes_session_cookie_names', 0, () => {
      expect(SessionCookiePolicy.isSessionCookieName('SUB')).assertTrue();
      expect(SessionCookiePolicy.isSessionCookieName('SSOLoginState')).assertTrue();
      expect(SessionCookiePolicy.isSessionCookieName('XSRF-TOKEN')).assertFalse();
    });

    it('preserves_typed_failure_details', 0, () => {
      const result: Result<string> = Result.fail<string>('', true, ApiFailureKind.AUTH_EXPIRED, 403);
      expect(result.failureKind).assertEqual(ApiFailureKind.AUTH_EXPIRED);
      expect(result.statusCode).assertEqual(403);
      expect(result.authRequired).assertTrue();
    });
  });
}
