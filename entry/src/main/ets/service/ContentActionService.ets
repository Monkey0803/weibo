import { common } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WeiboPost } from '../model/WeiboModels';

const CONTENT_ACTION_DOMAIN: number = 0x0000;
const CONTENT_ACTION_TAG: string = 'ContentAction';
const SUMMARY_LIMIT: number = 120;
const OFFICIAL_WEIBO_HTTPS_PATTERN: RegExp =
  /^https:\/\/([a-z0-9-]+\.)*(weibo\.com|weibo\.cn)(:443)?([\/?#]|$)/i;

export class ContentActionService {
  postUrl(post: WeiboPost): string {
    const identifier: string = post.mid.length > 0 ? post.mid : post.id;
    return identifier.length > 0 ? 'https://m.weibo.cn/detail/' + encodeURIComponent(identifier) : '';
  }

  profileUrl(userId: string): string {
    return userId.length > 0 ? 'https://m.weibo.cn/u/' + encodeURIComponent(userId) : '';
  }

  liveUrl(post: WeiboPost): string {
    const pageUrl: string = post.media.pageUrl;
    if (OFFICIAL_WEIBO_HTTPS_PATTERN.test(pageUrl)) {
      return pageUrl;
    }
    return this.postUrl(post);
  }

  postShareText(post: WeiboPost): string {
    const compact: string = post.text.replace(/\s+/g, ' ').trim();
    const summary: string = compact.length > SUMMARY_LIMIT ? compact.substring(0, SUMMARY_LIMIT) + '…' : compact;
    const prefix: string = post.user.name.length > 0 ? post.user.name + '：' : '';
    const url: string = this.postUrl(post);
    return url.length > 0 ? prefix + summary + '\n' + url : prefix + summary;
  }

  profileShareText(userId: string, userName: string): string {
    const url: string = this.profileUrl(userId);
    return userName.length > 0 ? userName + '\n' + url : url;
  }

  async copy(text: string): Promise<boolean> {
    if (text.length === 0) {
      return false;
    }
    try {
      const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await board.setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text));
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(CONTENT_ACTION_DOMAIN, CONTENT_ACTION_TAG, 'copy failed: %{public}d', error.code);
      return false;
    }
  }

  async shareText(context: common.UIAbilityContext, title: string, content: string): Promise<boolean> {
    if (content.length === 0) {
      return false;
    }
    try {
      const record: systemShare.SharedRecord = {
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        content: content,
        title: title
      };
      const data: systemShare.SharedData = new systemShare.SharedData(record);
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(CONTENT_ACTION_DOMAIN, CONTENT_ACTION_TAG, 'share failed: %{public}d', error.code);
      return false;
    }
  }

  async openLink(context: common.UIAbilityContext, url: string): Promise<boolean> {
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      return false;
    }
    try {
      await context.openLink(url);
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(CONTENT_ACTION_DOMAIN, CONTENT_ACTION_TAG, 'open link failed: %{public}d', error.code);
      return false;
    }
  }
}

export const contentActionService: ContentActionService = new ContentActionService();
