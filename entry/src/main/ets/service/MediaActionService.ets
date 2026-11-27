import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { http } from '@kit.NetworkKit';
import { systemShare } from '@kit.ShareKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WeiboSession } from './WeiboSession';

const MEDIA_DOMAIN: number = 0x0000;
const MEDIA_TAG: string = 'MediaAction';
const IMAGE_MAX_BYTES: number = 64 * 1024 * 1024;
const VIDEO_MAX_BYTES: number = 500 * 1024 * 1024;
const MEDIA_DIRECTORY: string = 'weibo-media-actions';
const STALE_MEDIA_AGE_SECONDS: number = 24 * 60 * 60;
const MAX_CACHE_BYTES: number = 1024 * 1024 * 1024;
const MAX_CACHE_FILES: number = 8;
const SHARE_DISMISS_GRACE_MS: number = 5 * 60 * 1000;

export enum MediaActionKind {
  IMAGE = 0,
  VIDEO = 1
}

export enum MediaActionStage {
  IDLE = 0,
  CONNECTING = 1,
  DOWNLOADING = 2,
  FAILED = 3
}

/** 媒体动作的纯策略，便于在不发起网络请求的情况下验证格式与体积限制。 */
export class MediaActionPolicy {
  static maxBytes(kind: MediaActionKind): number {
    return kind === MediaActionKind.IMAGE ? IMAGE_MAX_BYTES : VIDEO_MAX_BYTES;
  }

  static extension(url: string, kind: MediaActionKind): string {
    const clean: string = url.split('?')[0].toLowerCase();
    const extensions: string[] = kind === MediaActionKind.IMAGE
      ? ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'] : ['mp4', 'mov', 'm4v', 'webm'];
    for (let index: number = 0; index < extensions.length; index += 1) {
      if (clean.endsWith('.' + extensions[index])) {
        return extensions[index];
      }
    }
    return kind === MediaActionKind.IMAGE ? 'jpg' : 'mp4';
  }

  static acceptsContentType(contentType: string, kind: MediaActionKind): boolean {
    const normalized: string = contentType.toLowerCase();
    if (normalized.length === 0 || normalized.includes('octet-stream')) {
      return true;
    }
    return kind === MediaActionKind.IMAGE ? normalized.startsWith('image/') : normalized.startsWith('video/');
  }
}

export class MediaActionResult {
  readonly success: boolean;
  readonly cancelled: boolean;
  readonly path: string;
  readonly fileName: string;
  readonly message: string;

  constructor(success: boolean, cancelled: boolean = false, path: string = '', fileName: string = '',
    message: string = '') {
    this.success = success;
    this.cancelled = cancelled;
    this.path = path;
    this.fileName = fileName;
    this.message = message;
  }
}

class MediaCacheEntry {
  readonly path: string;
  readonly size: number;
  readonly mtime: number;

  constructor(path: string, size: number, mtime: number) {
    this.path = path;
    this.size = size;
    this.mtime = mtime;
  }
}

class MediaCacheUsage {
  readonly bytes: number;
  readonly files: number;

  constructor(bytes: number, files: number) {
    this.bytes = bytes;
    this.files = files;
  }
}

class MediaCacheRegistry {
  private static activePaths: Set<string> = new Set<string>();
  private static reservedBytes: number = 0;
  private static reservedFiles: number = 0;

  static activate(path: string): void {
    MediaCacheRegistry.activePaths.add(path);
  }

  static release(path: string): void {
    MediaCacheRegistry.activePaths.delete(path);
  }

  static isActive(path: string): boolean {
    return MediaCacheRegistry.activePaths.has(path);
  }

  static reserve(bytes: number, observed: MediaCacheUsage): boolean {
    if (observed.bytes + MediaCacheRegistry.reservedBytes + bytes > MAX_CACHE_BYTES ||
      observed.files + MediaCacheRegistry.reservedFiles + 1 > MAX_CACHE_FILES) {
      return false;
    }
    MediaCacheRegistry.reservedBytes += bytes;
    MediaCacheRegistry.reservedFiles += 1;
    return true;
  }

  static releaseReservation(bytes: number): void {
    MediaCacheRegistry.reservedBytes = Math.max(0, MediaCacheRegistry.reservedBytes - bytes);
    MediaCacheRegistry.reservedFiles = Math.max(0, MediaCacheRegistry.reservedFiles - 1);
  }

  static currentReservedBytes(): number {
    return MediaCacheRegistry.reservedBytes;
  }

  static currentReservedFiles(): number {
    return MediaCacheRegistry.reservedFiles;
  }
}

@ObservedV2
export class MediaActionController {
  @Trace stage: MediaActionStage = MediaActionStage.IDLE;
  @Trace receivedBytes: number = 0;
  @Trace totalBytes: number = 0;
  @Trace errorMessage: string = '';
  private transfer: MediaTransfer | undefined = undefined;

  busy(): boolean {
    return this.stage === MediaActionStage.CONNECTING || this.stage === MediaActionStage.DOWNLOADING;
  }

  progressPercent(): number {
    if (this.totalBytes <= 0) {
      return 0;
    }
    return Math.min(100, Math.floor(this.receivedBytes * 100 / this.totalBytes));
  }

  cancel(): void {
    this.transfer?.cancel();
  }

  reset(): void {
    this.stage = MediaActionStage.IDLE;
    this.receivedBytes = 0;
    this.totalBytes = 0;
    this.errorMessage = '';
  }

  async download(context: common.UIAbilityContext, url: string, kind: MediaActionKind): Promise<MediaActionResult> {
    this.cancel();
    this.reset();
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      this.stage = MediaActionStage.FAILED;
      this.errorMessage = 'invalid-url';
      return new MediaActionResult(false, false, '', '', this.errorMessage);
    }
    const transfer: MediaTransfer = new MediaTransfer();
    this.transfer = transfer;
    const result: MediaActionResult = await transfer.run(context, url, kind,
      (stage: MediaActionStage, received: number, total: number): void => {
        if (this.transfer !== transfer) {
          return;
        }
        this.stage = stage;
        this.receivedBytes = received;
        this.totalBytes = total;
      });
    if (this.transfer === transfer) {
      this.transfer = undefined;
      if (result.success || result.cancelled) {
        this.reset();
      } else {
        this.stage = MediaActionStage.FAILED;
        this.errorMessage = result.message;
      }
    }
    return result;
  }
}

class MediaTransfer {
  private request: http.HttpRequest | undefined = undefined;
  private output: fs.File | undefined = undefined;
  private partPath: string = '';
  private finished: boolean = false;
  private cancelled: boolean = false;
  private received: number = 0;
  private total: number = 0;
  private responseCode: number = 0;
  private responseComplete: boolean = false;
  private streamComplete: boolean = false;
  private maxBytes: number = 0;
  private contentType: string = '';
  private quotaReserved: boolean = false;
  private complete: ((result: MediaActionResult) => void) | undefined = undefined;
  private progress: (stage: MediaActionStage, received: number, total: number) => void =
    (_stage: MediaActionStage, _received: number, _total: number): void => {};

  cancel(): void {
    this.cancelled = true;
    this.finish('cancelled');
  }

  async run(context: common.UIAbilityContext, url: string, kind: MediaActionKind,
    progress: (stage: MediaActionStage, received: number, total: number) => void): Promise<MediaActionResult> {
    this.progress = progress;
    this.maxBytes = MediaActionPolicy.maxBytes(kind);
    this.progress(MediaActionStage.CONNECTING, 0, 0);
    const directory: string = context.cacheDir + '/' + MEDIA_DIRECTORY;
    try {
      if (!await fs.access(directory)) {
        await fs.mkdir(directory);
      }
      const usage: MediaCacheUsage = await this.removeOldFiles(directory, this.maxBytes);
      this.quotaReserved = MediaCacheRegistry.reserve(this.maxBytes, usage);
      if (!this.quotaReserved) {
        return new MediaActionResult(false, false, '', '', 'cache-limit');
      }
    } catch (error) {
      return new MediaActionResult(false, false, '', '', 'storage');
    }
    if (this.cancelled) {
      this.releaseQuota();
      return new MediaActionResult(false, true, '', '', 'cancelled');
    }
    const extension: string = MediaActionPolicy.extension(url, kind);
    const fileName: string = 'weibo-' + Date.now().toString() + '.' + extension;
    const finalPath: string = directory + '/' + fileName;
    this.partPath = finalPath + '.part';
    try {
      this.output = fs.openSync(this.partPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      MediaCacheRegistry.activate(this.partPath);
    } catch (error) {
      this.releaseQuota();
      return new MediaActionResult(false, false, '', '', 'storage');
    }
    if (this.cancelled) {
      this.finish('cancelled');
      return new MediaActionResult(false, true, '', '', 'cancelled');
    }
    const cookie: string = await WeiboSession.cookieFor(url);
    if (this.cancelled) {
      this.finish('cancelled');
      return new MediaActionResult(false, true, '', '', 'cancelled');
    }
    return new Promise<MediaActionResult>((resolve): void => {
      this.complete = resolve;
      try {
        const request: http.HttpRequest = http.createHttp();
        this.request = request;
        request.on('headersReceive', (headers: Object): void => this.receiveHeaders(headers, kind));
        request.on('dataReceive', (chunk: ArrayBuffer): void => this.receiveChunk(chunk));
        request.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo): void => {
          if (info.totalSize > 0) {
            this.total = info.totalSize;
          }
          this.progress(MediaActionStage.DOWNLOADING, this.received, this.total);
        });
        request.on('dataEnd', (): void => {
          this.streamComplete = true;
          this.finishIfReady(finalPath, fileName, kind);
        });
        const options: http.HttpRequestOptions = {
          method: http.RequestMethod.GET,
          header: {
            'Accept': kind === MediaActionKind.IMAGE ? 'image/*' : 'video/*',
            'Cookie': cookie,
            'Referer': WeiboSession.MOBILE_ORIGIN + '/',
            'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS; Mobile) AppleWebKit/537.36 Mobile Safari/537.36'
          },
          usingCache: false,
          maxLimit: this.maxBytes,
          maxRedirects: 5,
          connectTimeout: 15000,
          readTimeout: 120000
        };
        request.requestInStream(url, options).then((code: number): void => {
          this.responseCode = code;
          this.responseComplete = true;
          this.finishIfReady(finalPath, fileName, kind);
        }).catch((error: BusinessError): void => {
          hilog.warn(MEDIA_DOMAIN, MEDIA_TAG, 'download failed: %{public}d', error.code);
          this.finish('network');
        });
      } catch (error) {
        this.finish('network');
      }
    });
  }

  private receiveHeaders(headers: Object, kind: MediaActionKind): void {
    const serialized: string = JSON.stringify(headers);
    const lengthMatch: RegExpMatchArray | null = serialized.match(/"content-length"\s*:\s*"?(\d+)/i);
    if (lengthMatch !== null) {
      this.total = Number(lengthMatch[1]);
      if (this.total > this.maxBytes) {
        this.finish('size');
        return;
      }
    }
    const typeMatch: RegExpMatchArray | null = serialized.match(/"content-type"\s*:\s*"([^"]+)/i);
    this.contentType = typeMatch === null ? '' : typeMatch[1].toLowerCase();
    if (!MediaActionPolicy.acceptsContentType(this.contentType, kind)) {
      this.finish('type');
    }
  }

  private receiveChunk(chunk: ArrayBuffer): void {
    if (this.finished || this.output === undefined) {
      return;
    }
    if (this.received + chunk.byteLength > this.maxBytes) {
      this.finish('size');
      return;
    }
    try {
      if (fs.writeSync(this.output.fd, chunk) !== chunk.byteLength) {
        this.finish('storage');
        return;
      }
      this.received += chunk.byteLength;
      this.progress(MediaActionStage.DOWNLOADING, this.received, this.total);
    } catch (error) {
      this.finish('storage');
    }
  }

  private finishIfReady(finalPath: string, fileName: string, kind: MediaActionKind): void {
    if (this.finished || !this.responseComplete) {
      return;
    }
    if (this.responseCode < 200 || this.responseCode >= 300) {
      this.finish('http-' + this.responseCode.toString());
      return;
    }
    if (!this.streamComplete) {
      return;
    }
    if (this.received <= 0) {
      this.finish('empty');
      return;
    }
    this.closeOutput();
    try {
      fs.renameSync(this.partPath, finalPath);
      MediaCacheRegistry.release(this.partPath);
      this.partPath = '';
      MediaCacheRegistry.activate(finalPath);
      this.finished = true;
      this.releaseQuota();
      this.request?.destroy();
      this.request = undefined;
      this.complete?.(new MediaActionResult(true, false, finalPath, fileName));
      this.complete = undefined;
    } catch (error) {
      this.finish(kind === MediaActionKind.IMAGE ? 'image-file' : 'video-file');
    }
  }

  private finish(message: string): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.releaseQuota();
    this.closeOutput();
    try {
      this.request?.destroy();
    } catch (error) {
    }
    this.request = undefined;
    if (this.partPath.length > 0) {
      MediaCacheRegistry.release(this.partPath);
      try {
        fs.unlinkSync(this.partPath);
      } catch (error) {
      }
      this.partPath = '';
    }
    this.complete?.(new MediaActionResult(false, this.cancelled, '', '', message));
    this.complete = undefined;
  }

  private closeOutput(): void {
    if (this.output !== undefined) {
      try {
        fs.closeSync(this.output);
      } catch (error) {
      }
      this.output = undefined;
    }
  }

  private releaseQuota(): void {
    if (!this.quotaReserved) {
      return;
    }
    this.quotaReserved = false;
    MediaCacheRegistry.releaseReservation(this.maxBytes);
  }

  private async removeOldFiles(directory: string, reservedBytes: number): Promise<MediaCacheUsage> {
    let names: string[] = [];
    try {
      names = await fs.listFile(directory);
    } catch (error) {
      return new MediaCacheUsage(0, 0);
    }
    const entries: MediaCacheEntry[] = [];
    let totalBytes: number = 0;
    const nowSeconds: number = Date.now() / 1000;
    for (let index: number = 0; index < names.length; index += 1) {
      if (names[index].startsWith('weibo-')) {
        const path: string = directory + '/' + names[index];
        try {
          const stat: fs.Stat = fs.statSync(path);
          const ageSeconds: number = nowSeconds - stat.mtime;
          if (ageSeconds >= STALE_MEDIA_AGE_SECONDS && !MediaCacheRegistry.isActive(path)) {
            await fs.unlink(path);
          } else {
            entries.push(new MediaCacheEntry(path, stat.size, stat.mtime));
            totalBytes += stat.size;
          }
        } catch (error) {
        }
      }
    }
    entries.sort((left: MediaCacheEntry, right: MediaCacheEntry): number => left.mtime - right.mtime);
    while (entries.length + MediaCacheRegistry.currentReservedFiles() >= MAX_CACHE_FILES ||
      totalBytes + MediaCacheRegistry.currentReservedBytes() + reservedBytes > MAX_CACHE_BYTES) {
      let removableIndex: number = -1;
      for (let index: number = 0; index < entries.length; index += 1) {
        if (!MediaCacheRegistry.isActive(entries[index].path)) {
          removableIndex = index;
          break;
        }
      }
      if (removableIndex < 0) {
        break;
      }
      const removable: MediaCacheEntry = entries[removableIndex];
      let removed: boolean = false;
      try {
        await fs.unlink(removable.path);
        totalBytes -= removable.size;
        removed = true;
      } catch (error) {
      }
      if (!removed) {
        break;
      }
      entries.splice(removableIndex, 1);
    }
    return new MediaCacheUsage(totalBytes, entries.length);
  }
}

export class MediaActionService {
  async save(context: common.UIAbilityContext, controller: MediaActionController, url: string,
    kind: MediaActionKind): Promise<MediaActionResult> {
    const download: MediaActionResult = await controller.download(context, url, kind);
    if (!download.success) {
      return download;
    }
    try {
      const extension: string = download.fileName.substring(download.fileName.lastIndexOf('.') + 1);
      const title: string = download.fileName.substring(0, download.fileName.lastIndexOf('.'));
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      try {
        const config: photoAccessHelper.PhotoCreationConfig = {
          title: title,
          fileNameExtension: extension,
          photoType: kind === MediaActionKind.IMAGE
            ? photoAccessHelper.PhotoType.IMAGE : photoAccessHelper.PhotoType.VIDEO
        };
        const targets: string[] = await helper.showAssetsCreationDialog(
          [fileUri.getUriFromPath(download.path)], [config]);
        if (targets.length === 0) {
          this.remove(download.path);
          return new MediaActionResult(false, true, '', '', 'cancelled');
        }
        const source: fs.File = fs.openSync(download.path, fs.OpenMode.READ_ONLY);
        try {
          const target: fs.File = fs.openSync(targets[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
          try {
            await fs.copyFile(source.fd, target.fd);
          } finally {
            fs.closeSync(target);
          }
        } finally {
          fs.closeSync(source);
        }
      } finally {
        await helper.release();
      }
      this.remove(download.path);
      return new MediaActionResult(true);
    } catch (error) {
      this.remove(download.path);
      return new MediaActionResult(false, false, '', '', 'gallery');
    }
  }

  async share(context: common.UIAbilityContext, controller: MediaActionController, url: string,
    kind: MediaActionKind): Promise<MediaActionResult> {
    const download: MediaActionResult = await controller.download(context, url, kind);
    if (!download.success) {
      return download;
    }
    try {
      const record: systemShare.SharedRecord = {
        utd: kind === MediaActionKind.IMAGE
          ? uniformTypeDescriptor.UniformDataType.IMAGE : uniformTypeDescriptor.UniformDataType.VIDEO,
        uri: fileUri.getUriFromPath(download.path),
        title: download.fileName
      };
      const data: systemShare.SharedData = new systemShare.SharedData(record);
      const shareController: systemShare.ShareController = new systemShare.ShareController(data);
      let dismissTimer: number = -1;
      const onCompleted = (_result: systemShare.ShareOperationResult): void => {
        if (dismissTimer >= 0) {
          clearTimeout(dismissTimer);
          dismissTimer = -1;
        }
        this.remove(download.path);
        try {
          shareController.off('shareCompleted', onCompleted);
          shareController.off('dismiss', onDismissed);
        } catch (error) {
        }
      };
      const onDismissed = (): void => {
        if (dismissTimer >= 0) {
          return;
        }
        // 面板关闭可能早于接收方读取完成，保留宽限期并继续监听 shareCompleted。
        dismissTimer = setTimeout((): void => {
          MediaCacheRegistry.release(download.path);
          try {
            shareController.off('shareCompleted', onCompleted);
            shareController.off('dismiss', onDismissed);
          } catch (error) {
          }
          dismissTimer = -1;
        }, SHARE_DISMISS_GRACE_MS);
      };
      shareController.on('shareCompleted', onCompleted);
      shareController.on('dismiss', onDismissed);
      try {
        await shareController.show(context, {
          selectionMode: systemShare.SelectionMode.SINGLE,
          previewMode: systemShare.SharePreviewMode.DEFAULT
        });
      } catch (error) {
        if (dismissTimer >= 0) {
          clearTimeout(dismissTimer);
          dismissTimer = -1;
        }
        shareController.off('shareCompleted', onCompleted);
        shareController.off('dismiss', onDismissed);
        this.remove(download.path);
        return new MediaActionResult(false, false, '', '', 'share');
      }
      return new MediaActionResult(true);
    } catch (error) {
      this.remove(download.path);
      return new MediaActionResult(false, false, '', '', 'share');
    }
  }

  private remove(path: string): void {
    if (path.length === 0) {
      return;
    }
    try {
      fs.unlinkSync(path);
    } catch (error) {
    }
    MediaCacheRegistry.release(path);
  }
}

export const mediaActionService: MediaActionService = new MediaActionService();
