import settingsOptionsTest from './SettingsOptions.test';
import materialMapTest from './MaterialMap.test';
import imageSupportTest from './ImageSupport.test';
import constantsTest from './Constants.test';
import weiboParserTest from './WeiboParser.test';
import sessionCookiePolicyTest from './SessionCookiePolicy.test';

export default function testsuite() {
  settingsOptionsTest();
  materialMapTest();
  imageSupportTest();
  constantsTest();
  weiboParserTest();
  sessionCookiePolicyTest();
}
