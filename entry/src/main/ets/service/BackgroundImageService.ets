/* 系统图库返回的 URI 只有临时授权，选中后立即复制到应用沙箱供重启后继续使用。 */
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const BACKGROUND_FILE_PREFIX: string = 'global_background';

export class BackgroundPickResult {
  readonly path: string;
  readonly failed: boolean;

  constructor(path: string, failed: boolean) {
    this.path = path;
    this.failed = failed;
  }
}

export class BackgroundImageService {
  private nextFileId: number = 0;

  async pick(context: common.Context): Promise<BackgroundPickResult> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length === 0) {
        return new BackgroundPickResult('', false);
      }
      const path: string = this.copyToSandbox(context, result.photoUris[0]);
      return new BackgroundPickResult(path, path.length === 0);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('BackgroundImageService.pick failed: ' + error.code.toString());
      return new BackgroundPickResult('', true);
    }
  }

  toImageSource(path: string): string {
    if (path.length === 0) {
      return '';
    }
    try {
      return fileUri.getUriFromPath(path);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('BackgroundImageService.toImageSource failed: ' + error.code.toString());
      return '';
    }
  }

  exists(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      return fileIo.accessSync(path);
    } catch (err) {
      return false;
    }
  }

  remove(context: common.Context, path: string): void {
    const prefix: string = context.filesDir + '/' + BACKGROUND_FILE_PREFIX;
    if (path !== prefix && !path.startsWith(prefix + '_')) {
      return;
    }
    try {
      fileIo.unlinkSync(path);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.warn('BackgroundImageService.remove failed: ' + error.code.toString());
    }
  }

  private closeQuietly(file: fileIo.File): void {
    try {
      fileIo.closeSync(file);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('BackgroundImageService.close failed: ' + error.code.toString());
    }
  }

  private copyToSandbox(context: common.Context, uri: string): string {
    let target: string = '';
    do {
      target = context.filesDir + '/' + BACKGROUND_FILE_PREFIX + '_' + Date.now() + '_' + this.nextFileId;
      this.nextFileId += 1;
    } while (this.exists(target));
    try {
      const source: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        const destination: fileIo.File = fileIo.openSync(target,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          fileIo.copyFileSync(source.fd, destination.fd);
        } finally {
          this.closeQuietly(destination);
        }
      } finally {
        this.closeQuietly(source);
      }
      return target;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('BackgroundImageService.copy failed: ' + error.code.toString());
      if (this.exists(target)) {
        this.remove(context, target);
      }
      return '';
    }
  }
}

export const backgroundImageService: BackgroundImageService = new BackgroundImageService();
