import { AnimatedDrawableDescriptor, AnimationOptions } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { AnimatedImageFrames, animatedImageService } from '../service/AnimatedImageService';

@ComponentV2
export struct AnimatedNetworkImage {
  @Param imageUrl: string = '';
  @Param fitMode: ImageFit = ImageFit.Cover;
  @Param maxSidePx: number = 360;
  @Param memoryBudgetBytes: number = 12 * 1024 * 1024;
  @Event onTap: () => void = (): void => {};
  @Event onLoadFailed: () => void = (): void => {};
  @Local animatedSource: AnimatedDrawableDescriptor | undefined = undefined;
  private decodedFrames: AnimatedImageFrames | undefined = undefined;
  private loadGeneration: number = 0;
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.disposed = false;
    this.loadAnimation();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.loadGeneration += 1;
    this.releaseAnimation();
  }

  private async loadAnimation(): Promise<void> {
    const generation: number = ++this.loadGeneration;
    const frames: AnimatedImageFrames | undefined = await animatedImageService.load(
      this.imageUrl, this.maxSidePx, this.memoryBudgetBytes);
    if (frames === undefined) {
      return;
    }
    if (this.disposed || generation !== this.loadGeneration) {
      await frames.release();
      return;
    }
    try {
      const options: AnimationOptions = {
        frameDurations: frames.frameDurations,
        iterations: -1,
        autoPlay: true
      };
      this.animatedSource = new AnimatedDrawableDescriptor(frames.pixelMaps, options);
      this.decodedFrames = frames;
    } catch (error) {
      await frames.release();
    }
  }

  private async releaseAnimation(): Promise<void> {
    const frames: AnimatedImageFrames | undefined = this.decodedFrames;
    this.decodedFrames = undefined;
    this.animatedSource = undefined;
    if (frames !== undefined) {
      await frames.release();
    }
  }

  build() {
    if (this.animatedSource !== undefined) {
      Image(this.animatedSource)
        .width('100%')
        .height('100%')
        .objectFit(this.fitMode)
        .onClick(() => this.onTap())
    } else {
      Image(this.imageUrl)
        .width('100%')
        .height('100%')
        .objectFit(this.fitMode)
        .onError(() => this.onLoadFailed())
        .onClick(() => this.onTap())
    }
  }
}
