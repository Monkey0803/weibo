import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { WeiboSession } from './WeiboSession';
import { ImageSupport } from './ImageSupport';

const ANIMATED_IMAGE_MAX_BYTES: number = 20 * 1024 * 1024;

export class AnimatedImageFrames {
  readonly pixelMaps: Array<image.PixelMap>;
  readonly frameDurations: Array<number>;

  constructor(pixelMaps: Array<image.PixelMap>, frameDurations: Array<number>) {
    this.pixelMaps = pixelMaps;
    this.frameDurations = frameDurations;
  }

  async release(): Promise<void> {
    for (let index: number = 0; index < this.pixelMaps.length; index += 1) {
      try {
        await this.pixelMaps[index].release();
      } catch (error) {
        // A single failed release must not prevent the remaining animation frames from being freed.
      }
    }
  }
}

export class AnimatedImageService {
  static isCandidate(url: string): boolean {
    const queryIndex: number = url.indexOf('?');
    const cleanUrl: string = (queryIndex >= 0 ? url.substring(0, queryIndex) : url).toLowerCase();
    return cleanUrl.endsWith('.gif') || cleanUrl.endsWith('.webp');
  }

  async load(url: string, maxSidePx: number, memoryBudgetBytes: number): Promise<AnimatedImageFrames | undefined> {
    if (!AnimatedImageService.isCandidate(url)) {
      return undefined;
    }
    const buffer: ArrayBuffer | undefined = await this.download(url);
    if (buffer === undefined || !ImageSupport.isAnimatedFormat(buffer)) {
      return undefined;
    }
    const source: image.ImageSource = image.createImageSource(buffer);
    try {
      const frameCount: number = await source.getFrameCount();
      if (frameCount <= 1) {
        return undefined;
      }
      const info: image.ImageInfo = await source.getImageInfo();
      const desiredSize: image.Size = this.desiredSize(info.size, frameCount, maxSidePx, memoryBudgetBytes);
      const options: image.DecodingOptions = {
        desiredSize: desiredSize,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      const pixelMaps: Array<image.PixelMap> = await source.createPixelMapList(options);
      if (pixelMaps.length <= 1) {
        await this.releasePixelMaps(pixelMaps);
        return undefined;
      }
      const frameDurations: Array<number> = this.normalizeDurations(
        await source.getDelayTimeList(), pixelMaps.length);
      return new AnimatedImageFrames(pixelMaps, frameDurations);
    } catch (error) {
      return undefined;
    } finally {
      try {
        await source.release();
      } catch (error) {
        // Decoding already has a safe static-image fallback; release failures must not break it.
      }
    }
  }

  private async download(url: string): Promise<ArrayBuffer | undefined> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const cookie: string = await WeiboSession.cookieFor(url);
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: true,
        maxLimit: ANIMATED_IMAGE_MAX_BYTES,
        maxRedirects: 5,
        connectTimeout: 15000,
        readTimeout: 30000,
        header: {
          'Accept': 'image/gif,image/webp,image/*',
          'Cookie': cookie,
          'Referer': WeiboSession.MOBILE_ORIGIN + '/',
          'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS; Mobile) AppleWebKit/537.36 Mobile Safari/537.36'
        }
      };
      const response: http.HttpResponse = await request.request(url, options);
      if (response.responseCode < 200 || response.responseCode >= 300 ||
        response.resultType !== http.HttpDataType.ARRAY_BUFFER) {
        return undefined;
      }
      return response.result as ArrayBuffer;
    } catch (error) {
      return undefined;
    } finally {
      request.destroy();
    }
  }

  private desiredSize(original: image.Size, frameCount: number, maxSidePx: number,
    memoryBudgetBytes: number): image.Size {
    const originalPixels: number = Math.max(1, original.width * original.height);
    const sideScale: number = Math.min(1, maxSidePx / Math.max(original.width, original.height));
    const memoryScale: number = Math.sqrt(memoryBudgetBytes / Math.max(1, frameCount * 4 * originalPixels));
    const scale: number = Math.min(sideScale, memoryScale);
    return {
      width: Math.max(1, Math.round(original.width * scale)),
      height: Math.max(1, Math.round(original.height * scale))
    };
  }

  private normalizeDurations(sourceDurations: Array<number>, frameCount: number): Array<number> {
    const durations: Array<number> = [];
    for (let index: number = 0; index < frameCount; index += 1) {
      const duration: number = sourceDurations[index] ?? 100;
      durations.push(duration > 0 ? duration : 100);
    }
    return durations;
  }

  private async releasePixelMaps(pixelMaps: Array<image.PixelMap>): Promise<void> {
    for (let index: number = 0; index < pixelMaps.length; index += 1) {
      try {
        await pixelMaps[index].release();
      } catch (error) {
        // Continue releasing the remaining frames.
      }
    }
  }
}

export const animatedImageService: AnimatedImageService = new AnimatedImageService();
