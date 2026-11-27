import settingsOptionsTest from './SettingsOptions.test';
import materialMapTest from './MaterialMap.test';
import imageSupportTest from './ImageSupport.test';
import constantsTest from './Constants.test';
import weiboParserTest from './WeiboParser.test';
import postDateFormatterTest from './PostDateFormatter.test';
import sessionCookiePolicyTest from './SessionCookiePolicy.test';
import menuSpecTest from './MenuSpec.test';
import contentActionServiceTest from './ContentActionService.test';
import mediaActionPolicyTest from './MediaActionPolicy.test';
import videoPlayerSupportTest from './VideoPlayerSupport.test';
import socialTextParserTest from './SocialTextParser.test';
import weiboRequestPolicyTest from './WeiboRequestPolicy.test';
import detailViewModelTest from './DetailViewModel.test';
import socialEntityInteractionGuardTest from './SocialEntityInteractionGuard.test';
import safeAreaControllerTest from './SafeAreaController.test';
import fullscreenSystemBarControllerTest from './FullscreenSystemBarController.test';

export default function testsuite() {
  settingsOptionsTest();
  materialMapTest();
  imageSupportTest();
  constantsTest();
  weiboParserTest();
  postDateFormatterTest();
  sessionCookiePolicyTest();
  menuSpecTest();
  contentActionServiceTest();
  mediaActionPolicyTest();
  videoPlayerSupportTest();
  socialTextParserTest();
  weiboRequestPolicyTest();
  detailViewModelTest();
  socialEntityInteractionGuardTest();
  safeAreaControllerTest();
  fullscreenSystemBarControllerTest();
}
