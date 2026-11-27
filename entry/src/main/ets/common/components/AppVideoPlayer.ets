import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { appSettings } from '../../model/AppSettings';
import { VIDEO_PLAYBACK_RATE_OPTIONS } from '../../model/SettingsOptions';
import { contentActionService } from '../../service/ContentActionService';
import { fullscreenSystemBars } from '../../service/FullscreenSystemBarController';
import { inlineVideoCoordinator } from '../../service/InlineVideoCoordinator';
import {
  mediaActionService,
  MediaActionController,
  MediaActionKind,
  MediaActionResult
} from '../../service/MediaActionService';
import { MaterialController } from '../../service/MaterialController';
import { notificationService } from '../../service/NotificationService';
import { safeArea } from '../../service/SafeAreaController';
import { AppMenu } from './AppMenu';
import { MediaActionOverlay } from './MediaActionOverlay';
import { MenuItemSpec, MenuSpec } from './MenuSpec';
import { videoPlaybackMenuSection } from './VideoPlaybackMenu';

const VIDEO_CONTROLS_HIDE_DELAY_MS: number = 3000;
const VIDEO_SEEK_STEP_SECONDS: number = 0.1;

export enum VideoFullscreenPhase {
  INLINE = 0,
  ENTERING = 1,
  ACTIVE = 2,
  EXITING = 3,
  DISPOSED = 4
}

/** 全屏播放器只有在浮层已出现且视频准备完成后才能执行一次进度迁移。 */
export function canActivateFullscreen(phase: VideoFullscreenPhase, coverAppeared: boolean,
  videoPrepared: boolean, transferApplied: boolean): boolean {
  return phase === VideoFullscreenPhase.ENTERING && coverAppeared && videoPrepared && !transferApplied;
}

/** 屏蔽上一轮全屏会话在快速退出或组件销毁后送达的异步回调。 */
export function acceptsFullscreenSession(activeSession: number, callbackSession: number,
  phase: VideoFullscreenPhase): boolean {
  return activeSession === callbackSession && phase !== VideoFullscreenPhase.INLINE &&
    phase !== VideoFullscreenPhase.DISPOSED;
}

/** 退出全屏时以用户在全屏中的最新播放意图为准；仅未完成迁移时沿用进入前状态。 */
export function shouldResumeInlineAfterFullscreen(previousPhase: VideoFullscreenPhase,
  playbackActive: boolean, entryShouldResume: boolean): boolean {
  if (previousPhase === VideoFullscreenPhase.ENTERING) {
    return entryShouldResume;
  }
  return previousPhase === VideoFullscreenPhase.ACTIVE && playbackActive;
}

/** 将秒数格式化为视频控制栏使用的 mm:ss / h:mm:ss。 */
export function formatVideoPlaybackTime(seconds: number): string {
  const safeSeconds: number = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0;
  const hours: number = Math.floor(safeSeconds / 3600);
  const minutes: number = Math.floor((safeSeconds % 3600) / 60);
  const remainingSeconds: number = safeSeconds % 60;
  const minuteText: string = hours > 0 ? minutes.toString().padStart(2, '0') : minutes.toString();
  const secondText: string = remainingSeconds.toString().padStart(2, '0');
  return hours > 0 ? hours.toString() + ':' + minuteText + ':' + secondText : minuteText + ':' + secondText;
}

@ComponentV2
export struct AppVideoPlayer {
  @Param videoUrl: string = '';
  @Param posterUrl: string = '';
  @Param playerHeight: Length = '100%';
  @Param playerRadius: Length = 0;
  @Param coordinateInlinePlayback: boolean = false;
  @Param pauseWhenHidden: boolean = false;

  @Local playerFailed: boolean = false;
  @Local playbackRateOverride: string = '';
  @Local playbackTimeSeconds: number = 0;
  @Local videoDurationSeconds: number = 0;
  @Local playbackActive: boolean = false;
  @Local progressSeeking: boolean = false;
  @Local controlsVisible: boolean = true;
  @Local fullscreenVisible: boolean = false;

  private inlineController: VideoController = new VideoController();
  private fullscreenController: VideoController = new VideoController();
  private mediaActions: MediaActionController = new MediaActionController();
  private controlsTimer: number = -1;
  private fullscreenStartTimeSeconds: number = 0;
  private fullscreenShouldResume: boolean = false;
  private fullscreenTransferCompleted: boolean = false;
  private inlineResumeAfterFullscreen: boolean = false;
  @Local private fullscreenPhase: VideoFullscreenPhase = VideoFullscreenPhase.INLINE;
  private fullscreenSession: number = 0;
  @Local private fullscreenViewSession: number = 0;
  private fullscreenCoverAppeared: boolean = false;
  private fullscreenVideoPrepared: boolean = false;
  private fullscreenTransferApplied: boolean = false;
  private playbackTransferTimer: number = -1;
  private disposed: boolean = false;
  private previousOrientation: window.Orientation = window.Orientation.UNSPECIFIED;
  private previousOrientationCaptured: boolean = false;
  private orientationRequest: Promise<void> | undefined = undefined;
  private orientationChanged: boolean = false;
  private systemBarsOwner: number = 0;

  aboutToAppear(): void {
    this.disposed = false;
    if (this.fullscreenPhase === VideoFullscreenPhase.DISPOSED) {
      this.fullscreenPhase = VideoFullscreenPhase.INLINE;
    }
    if (this.coordinateInlinePlayback) {
      inlineVideoCoordinator.register(this.inlineController);
    }
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.fullscreenSession += 1;
    this.fullscreenPhase = VideoFullscreenPhase.DISPOSED;
    this.clearControlsTimer();
    this.clearPlaybackTransferTimer();
    this.mediaActions.cancel();
    this.safeStop(this.inlineController);
    this.safeStop(this.fullscreenController);
    if (this.coordinateInlinePlayback) {
      inlineVideoCoordinator.unregister(this.inlineController);
    }
    this.restoreFullscreenWindow();
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private videoPlaybackRate(): string {
    const rateId: string = this.playbackRateOverride.length > 0
      ? this.playbackRateOverride : appSettings.videoPlaybackRate;
    return VIDEO_PLAYBACK_RATE_OPTIONS.normalize(rateId);
  }

  private setVideoPlaybackRate(rateId: string): void {
    this.playbackRateOverride = VIDEO_PLAYBACK_RATE_OPTIONS.normalize(rateId);
    this.showControls();
  }

  private activeController(): VideoController {
    return this.fullscreenVisible ? this.fullscreenController : this.inlineController;
  }

  private playbackControlsEnabled(): boolean {
    return this.fullscreenPhase === VideoFullscreenPhase.INLINE ||
      this.fullscreenPhase === VideoFullscreenPhase.ACTIVE;
  }

  private sliderMaximum(): number {
    return Math.max(VIDEO_SEEK_STEP_SECONDS, this.videoDurationSeconds);
  }

  private clearControlsTimer(): void {
    if (this.controlsTimer >= 0) {
      clearTimeout(this.controlsTimer);
      this.controlsTimer = -1;
    }
  }

  private clearPlaybackTransferTimer(): void {
    if (this.playbackTransferTimer >= 0) {
      clearTimeout(this.playbackTransferTimer);
      this.playbackTransferTimer = -1;
    }
  }

  private safeStart(controller: VideoController): void {
    try {
      controller.start();
    } catch (_error) {
    }
  }

  private safePause(controller: VideoController): void {
    try {
      controller.pause();
    } catch (_error) {
    }
  }

  private safeStop(controller: VideoController): void {
    try {
      controller.stop();
    } catch (_error) {
    }
  }

  private safeSeek(controller: VideoController, seconds: number): void {
    try {
      controller.setCurrentTime(seconds);
    } catch (_error) {
    }
  }

  private scheduleControlsHide(): void {
    this.clearControlsTimer();
    if (!this.playbackActive || !this.controlsVisible || this.progressSeeking || this.mediaActions.busy()) {
      return;
    }
    this.controlsTimer = setTimeout((): void => {
      this.controlsVisible = false;
      this.controlsTimer = -1;
    }, VIDEO_CONTROLS_HIDE_DELAY_MS);
  }

  private showControls(): void {
    this.controlsVisible = true;
    this.scheduleControlsHide();
  }

  private holdControls(): void {
    this.controlsVisible = true;
    this.clearControlsTimer();
  }

  private toggleControls(): void {
    if (this.controlsVisible) {
      this.controlsVisible = false;
      this.clearControlsTimer();
      return;
    }
    this.showControls();
  }

  private togglePlayback(): void {
    if (!this.playbackControlsEnabled()) {
      return;
    }
    this.showControls();
    if (this.playbackActive) {
      this.safePause(this.activeController());
      return;
    }
    if (!this.fullscreenVisible && this.coordinateInlinePlayback) {
      inlineVideoCoordinator.activate(this.inlineController);
    }
    this.safeStart(this.activeController());
  }

  private togglePlaybackFromDoubleTap(): void {
    if (this.videoUrl.length === 0 || this.playerFailed || this.mediaActions.busy()) {
      return;
    }
    this.togglePlayback();
  }

  private eventMatchesActivePlayer(fullscreenMode: boolean): boolean {
    return fullscreenMode === this.fullscreenVisible;
  }

  private acceptsPlaybackEvent(fullscreenMode: boolean, session: number): boolean {
    if (!fullscreenMode) {
      return this.eventMatchesActivePlayer(false);
    }
    return this.eventMatchesActivePlayer(true) && this.fullscreenPhase === VideoFullscreenPhase.ACTIVE &&
      acceptsFullscreenSession(this.fullscreenSession, session, this.fullscreenPhase);
  }

  private onPlaybackStarted(fullscreenMode: boolean, session: number = 0): void {
    if (!this.acceptsPlaybackEvent(fullscreenMode, session)) {
      return;
    }
    this.playbackActive = true;
    this.scheduleControlsHide();
  }

  private onPlaybackPaused(fullscreenMode: boolean, session: number = 0): void {
    if (!this.acceptsPlaybackEvent(fullscreenMode, session)) {
      return;
    }
    this.playbackActive = false;
    this.showControls();
  }

  private onPlaybackFinished(fullscreenMode: boolean, session: number = 0): void {
    if (!this.acceptsPlaybackEvent(fullscreenMode, session)) {
      return;
    }
    this.playbackActive = false;
    this.playbackTimeSeconds = this.videoDurationSeconds;
    this.showControls();
  }

  private onPrepared(info: PreparedInfo): void {
    this.videoDurationSeconds = info.duration;
  }

  private onPlaybackUpdate(info: PlaybackInfo, fullscreenMode: boolean, session: number = 0): void {
    if (this.acceptsPlaybackEvent(fullscreenMode, session) && !this.progressSeeking) {
      this.playbackTimeSeconds = info.time;
    }
  }

  private onPlaybackError(fullscreenMode: boolean, session: number = 0): void {
    if (this.acceptsPlaybackEvent(fullscreenMode, session)) {
      this.playerFailed = true;
    }
  }

  private onFullscreenPrepared(info: PreparedInfo, session: number): void {
    if (!acceptsFullscreenSession(this.fullscreenSession, session, this.fullscreenPhase)) {
      return;
    }
    this.videoDurationSeconds = info.duration;
    this.fullscreenVideoPrepared = true;
    this.activateFullscreenIfReady(session);
  }

  private changeProgress(nextTime: number, mode: SliderChangeMode): void {
    if (!this.playbackControlsEnabled()) {
      return;
    }
    this.playbackTimeSeconds = nextTime;
    if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
      this.progressSeeking = true;
      this.holdControls();
      return;
    }
    this.safeSeek(this.activeController(), nextTime);
    this.progressSeeking = false;
    this.scheduleControlsHide();
  }

  private async setSensorOrientation(session: number): Promise<void> {
    if (!this.isFullscreenSessionActive(session) || this.orientationRequest !== undefined) {
      return;
    }
    try {
      const mainWindow: window.Window = this.hostContext().windowStage.getMainWindowSync();
      this.previousOrientation = mainWindow.getPreferredOrientation();
      this.previousOrientationCaptured = true;
      const request: Promise<void> = mainWindow
        .setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
        .then((): void => {
          this.orientationChanged = true;
        })
        .catch((_error: BusinessError): void => {
          this.orientationChanged = false;
          this.previousOrientationCaptured = false;
        });
      this.orientationRequest = request;
      await request;
      if (this.orientationRequest === request) {
        this.orientationRequest = undefined;
      }
      if (!this.isFullscreenSessionActive(session)) {
        await this.restoreOrientation();
      }
    } catch (_error) {
      this.orientationChanged = false;
      this.previousOrientationCaptured = false;
      this.orientationRequest = undefined;
    }
  }

  private isFullscreenSessionActive(session: number): boolean {
    return !this.disposed && session === this.fullscreenSession &&
      this.fullscreenPhase === VideoFullscreenPhase.ACTIVE;
  }

  private async restoreOrientation(): Promise<void> {
    const pendingRequest: Promise<void> | undefined = this.orientationRequest;
    if (pendingRequest !== undefined) {
      await pendingRequest;
    }
    if (!this.previousOrientationCaptured || !this.orientationChanged) {
      return;
    }
    this.orientationChanged = false;
    this.previousOrientationCaptured = false;
    try {
      const mainWindow: window.Window = this.hostContext().windowStage.getMainWindowSync();
      await mainWindow.setPreferredOrientation(this.previousOrientation);
    } catch (_error) {
    }
  }

  private hideSystemBars(session: number): void {
    if (!acceptsFullscreenSession(this.fullscreenSession, session, this.fullscreenPhase) || this.disposed ||
      this.systemBarsOwner > 0) {
      return;
    }
    try {
      const mainWindow: window.Window = this.hostContext().windowStage.getMainWindowSync();
      this.systemBarsOwner = fullscreenSystemBars.acquire(mainWindow);
    } catch (_error) {
      this.systemBarsOwner = 0;
    }
  }

  private async restoreSystemBars(): Promise<void> {
    const owner: number = this.systemBarsOwner;
    if (owner <= 0) {
      return;
    }
    this.systemBarsOwner = 0;
    await fullscreenSystemBars.release(owner);
  }

  private async restoreFullscreenWindow(): Promise<void> {
    const systemBarsRestore: Promise<void> = this.restoreSystemBars();
    await this.restoreOrientation();
    await systemBarsRestore;
  }

  private openFullscreen(): void {
    if (this.videoUrl.length === 0 || this.fullscreenPhase !== VideoFullscreenPhase.INLINE || this.disposed) {
      return;
    }
    this.fullscreenSession += 1;
    this.fullscreenViewSession = this.fullscreenSession;
    this.fullscreenPhase = VideoFullscreenPhase.ENTERING;
    this.fullscreenStartTimeSeconds = this.playbackTimeSeconds;
    this.fullscreenShouldResume = this.playbackActive;
    this.fullscreenTransferCompleted = false;
    this.fullscreenCoverAppeared = false;
    this.fullscreenVideoPrepared = false;
    this.fullscreenTransferApplied = false;
    this.safePause(this.inlineController);
    this.controlsVisible = true;
    this.clearControlsTimer();
    this.clearPlaybackTransferTimer();
    this.fullscreenVisible = true;
  }

  private onFullscreenCoverAppeared(): void {
    const session: number = this.fullscreenViewSession;
    if (!acceptsFullscreenSession(this.fullscreenSession, session, this.fullscreenPhase)) {
      return;
    }
    this.fullscreenCoverAppeared = true;
    this.activateFullscreenIfReady(session);
  }

  private onFullscreenCoverWillAppear(): void {
    const session: number = this.fullscreenViewSession;
    if (acceptsFullscreenSession(this.fullscreenSession, session, this.fullscreenPhase)) {
      this.hideSystemBars(session);
    }
  }

  private activateFullscreenIfReady(session: number): void {
    if (!acceptsFullscreenSession(this.fullscreenSession, session, this.fullscreenPhase) ||
      !canActivateFullscreen(this.fullscreenPhase, this.fullscreenCoverAppeared,
        this.fullscreenVideoPrepared, this.fullscreenTransferApplied)) {
      return;
    }
    this.fullscreenTransferApplied = true;
    this.fullscreenPhase = VideoFullscreenPhase.ACTIVE;
    this.safeSeek(this.fullscreenController, this.fullscreenStartTimeSeconds);
    if (this.fullscreenShouldResume) {
      this.playbackTransferTimer = setTimeout((): void => {
        this.playbackTransferTimer = -1;
        if (!this.disposed && this.fullscreenPhase === VideoFullscreenPhase.ACTIVE &&
          session === this.fullscreenSession) {
          this.safeStart(this.fullscreenController);
        }
      }, 0);
    }
    this.setSensorOrientation(session);
  }

  private beginFullscreenExit(): void {
    if (this.fullscreenTransferCompleted || this.fullscreenPhase === VideoFullscreenPhase.INLINE ||
      this.fullscreenPhase === VideoFullscreenPhase.DISPOSED) {
      return;
    }
    const previousPhase: VideoFullscreenPhase = this.fullscreenPhase;
    this.fullscreenTransferCompleted = true;
    this.fullscreenPhase = VideoFullscreenPhase.EXITING;
    this.clearPlaybackTransferTimer();
    const resumeTime: number = this.playbackTimeSeconds;
    this.fullscreenStartTimeSeconds = resumeTime;
    this.inlineResumeAfterFullscreen = shouldResumeInlineAfterFullscreen(previousPhase,
      this.playbackActive, this.fullscreenShouldResume);
    this.safePause(this.fullscreenController);
    this.fullscreenVisible = false;
  }

  private async onFullscreenDisappeared(): Promise<void> {
    const session: number = this.fullscreenViewSession;
    if (this.fullscreenPhase !== VideoFullscreenPhase.EXITING) {
      return;
    }
    this.safeStop(this.fullscreenController);
    await this.restoreFullscreenWindow();
    if (this.disposed || session !== this.fullscreenSession ||
      this.fullscreenPhase !== VideoFullscreenPhase.EXITING) {
      return;
    }
    this.safeSeek(this.inlineController, this.fullscreenStartTimeSeconds);
    this.fullscreenTransferCompleted = false;
    this.fullscreenCoverAppeared = false;
    this.fullscreenVideoPrepared = false;
    this.fullscreenTransferApplied = false;
    this.fullscreenShouldResume = false;
    this.fullscreenPhase = VideoFullscreenPhase.INLINE;
    if (this.inlineResumeAfterFullscreen) {
      this.inlineResumeAfterFullscreen = false;
      if (this.coordinateInlinePlayback) {
        inlineVideoCoordinator.activate(this.inlineController);
      }
      this.playbackTransferTimer = setTimeout((): void => {
        this.playbackTransferTimer = -1;
        if (!this.disposed && this.fullscreenPhase === VideoFullscreenPhase.INLINE &&
          session === this.fullscreenSession) {
          this.safeStart(this.inlineController);
        }
      }, 0);
    }
    this.scheduleControlsHide();
  }

  private closeFullscreen(): void {
    this.beginFullscreenExit();
  }

  private notifyMediaResult(result: MediaActionResult, isShare: boolean = false): void {
    if (result.success) {
      if (!isShare) {
        notificationService.showSuccess(this.getUIContext(), $r('app.string.notice_media_saved'));
      }
      return;
    }
    if (result.cancelled) {
      notificationService.showInfo(this.getUIContext(), $r('app.string.notice_media_cancelled'));
      return;
    }
    notificationService.showError(this.getUIContext(), isShare && result.message === 'share'
      ? $r('app.string.notice_share_failed') : $r('app.string.notice_media_failed'));
  }

  private async saveVideo(): Promise<void> {
    this.holdControls();
    this.notifyMediaResult(await mediaActionService.save(this.hostContext(), this.mediaActions,
      this.videoUrl, MediaActionKind.VIDEO));
    this.scheduleControlsHide();
  }

  private async shareVideo(): Promise<void> {
    this.holdControls();
    this.notifyMediaResult(await mediaActionService.share(this.hostContext(), this.mediaActions,
      this.videoUrl, MediaActionKind.VIDEO), true);
    this.scheduleControlsHide();
  }

  private async copyVideoLink(): Promise<void> {
    const success: boolean = await contentActionService.copy(this.videoUrl);
    if (success) {
      notificationService.showSuccess(this.getUIContext(), $r('app.string.notice_copied'));
    } else {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_copy_failed'));
    }
    this.scheduleControlsHide();
  }

  private async openVideoLink(): Promise<void> {
    if (!await contentActionService.openLink(this.hostContext(), this.videoUrl)) {
      notificationService.showError(this.getUIContext(), $r('app.string.notice_open_failed'));
    }
    this.scheduleControlsHide();
  }

  private retryPlayback(): void {
    if (!this.playbackControlsEnabled()) {
      return;
    }
    this.playerFailed = false;
    const controller: VideoController = this.activeController();
    controller.reset();
    setTimeout((): void => controller.start(), 0);
  }

  private videoMenuSpec(): MenuSpec {
    const available: boolean = this.videoUrl.length > 0 && !this.mediaActions.busy();
    return MenuSpec.fromItems([
      new MenuItemSpec('save-video', $r('app.string.action_save_video'), () => this.saveVideo())
        .withEnabled(available),
      new MenuItemSpec('share-video', $r('app.string.action_share_video'), () => this.shareVideo())
        .withEnabled(available),
      new MenuItemSpec('copy-video-link', $r('app.string.action_copy_link'), () => this.copyVideoLink())
        .withEnabled(available),
      new MenuItemSpec('open-video-link', $r('app.string.action_open_browser'), () => this.openVideoLink())
        .withEnabled(available)
    ]);
  }

  private videoSpeedMenuSpec(): MenuSpec {
    return MenuSpec.fromSections([
      videoPlaybackMenuSection(this.videoPlaybackRate(), (rateId: string) => this.setVideoPlaybackRate(rateId))
    ]);
  }

  @Builder
  VideoMenu() {
    AppMenu(this.videoMenuSpec());
  }

  @Builder
  VideoSpeedMenu() {
    AppMenu(this.videoSpeedMenuSpec());
  }

  @Builder
  TopControls() {
    Row({ space: $r('app.float.space_xs') }) {
      Blank()
      Button() {
        Text(VIDEO_PLAYBACK_RATE_OPTIONS.labelOf(this.videoPlaybackRate()))
          .fontSize($r('app.float.font_size_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.white'))
      }
      .width($r('app.float.video_speed_control_width'))
      .height($r('app.float.preview_control_size'))
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.menu_video_speed'))
      .onClick(() => this.holdControls())
      .bindMenu(this.VideoSpeedMenu(), MaterialController.menuOptions(appSettings.immersiveOn))
      Button() {
        SymbolGlyph($r('sys.symbol.ellipsis_circle'))
          .fontSize($r('app.float.icon_size_small'))
          .fontColor([$r('sys.color.white')])
      }
      .width($r('app.float.preview_control_size'))
      .height($r('app.float.preview_control_size'))
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.action_more'))
      .onClick(() => this.holdControls())
      .bindMenu(this.VideoMenu(), MaterialController.menuOptions(appSettings.immersiveOn))
    }
    .width('100%')
    .padding({ left: $r('app.float.space_s'), right: $r('app.float.space_s') })
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.hm_preview_control'), 0.0], [Color.Transparent, 1.0]]
    })
  }

  @Builder
  PlaybackControls(fullscreenMode: boolean) {
    Row({ space: $r('app.float.space_xs') }) {
      Button() {
        if (this.playbackActive) {
          SymbolGlyph($r('sys.symbol.pause_fill'))
            .fontSize($r('app.float.icon_size'))
            .fontColor([$r('sys.color.white')])
        } else {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize($r('app.float.icon_size'))
            .fontColor([$r('sys.color.white')])
        }
      }
      .width($r('app.float.preview_control_size'))
      .height($r('app.float.preview_control_size'))
      .padding(0)
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor(Color.Transparent)
      .enabled(this.playbackControlsEnabled())
      .accessibilityText(this.playbackActive
        ? $r('app.string.action_pause_video') : $r('app.string.action_play_video'))
      .onClick(() => this.togglePlayback())
      Text(formatVideoPlaybackTime(this.playbackTimeSeconds))
        .fontSize($r('app.float.font_size_metric'))
        .fontColor($r('sys.color.white'))
        .fontFeature('tnum')
      Slider({
        value: this.playbackTimeSeconds,
        min: 0,
        max: this.sliderMaximum(),
        step: VIDEO_SEEK_STEP_SECONDS,
        style: SliderStyle.InSet
      })
        .enabled(this.playbackControlsEnabled())
        .selectedColor($r('sys.color.white'))
        .trackColor($r('app.color.hm_preview_control'))
        .blockColor($r('sys.color.white'))
        .trackThickness($r('app.float.video_progress_track_height'))
        .blockSize({
          width: $r('app.float.video_progress_thumb_size'),
          height: $r('app.float.video_progress_thumb_size')
        })
        .layoutWeight(1)
        .onChange((nextTime: number, mode: SliderChangeMode) => this.changeProgress(nextTime, mode))
      Text(formatVideoPlaybackTime(this.videoDurationSeconds))
        .fontSize($r('app.float.font_size_metric'))
        .fontColor($r('sys.color.white'))
        .fontFeature('tnum')
      Button() {
        if (fullscreenMode) {
          SymbolGlyph($r('sys.symbol.arrow_down_right_and_arrow_up_left'))
            .fontSize($r('app.float.icon_size'))
            .fontColor([$r('sys.color.white')])
        } else {
          SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
            .fontSize($r('app.float.icon_size'))
            .fontColor([$r('sys.color.white')])
        }
      }
      .width($r('app.float.preview_control_size'))
      .height($r('app.float.preview_control_size'))
      .padding(0)
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .backgroundColor(Color.Transparent)
      .accessibilityText(fullscreenMode
        ? $r('app.string.action_exit_fullscreen') : $r('app.string.action_enter_fullscreen'))
      .onClick(() => {
        if (fullscreenMode) {
          this.closeFullscreen();
        } else {
          this.openFullscreen();
        }
      })
    }
    .width('100%')
    .padding({
      left: $r('app.float.space_s'),
      right: $r('app.float.space_s')
    })
    .linearGradient({
      angle: 0,
      colors: [[$r('app.color.hm_preview_control'), 0.0], [Color.Transparent, 1.0]]
    })
  }

  @Builder
  ControlsOverlay(fullscreenMode: boolean) {
    Column() {
      this.TopControls()
      Blank()
      this.PlaybackControls(fullscreenMode)
    }
    .width('100%')
    .height('100%')
    .padding({
      top: fullscreenMode ? safeArea.videoTopInsetVp : 0,
      bottom: fullscreenMode ? safeArea.videoBottomInsetVp : 0,
      left: fullscreenMode ? safeArea.videoLeftInsetVp : 0,
      right: fullscreenMode ? safeArea.videoRightInsetVp : 0
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Up) {
        event.stopPropagation();
      }
    })
  }

  @Builder
  PlaybackError() {
    Column({ space: $r('app.float.space_s') }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize($r('app.float.icon_size'))
        .fontColor([$r('sys.color.white')])
      Text($r('app.string.video_error'))
        .fontSize($r('app.float.font_size_caption'))
        .fontColor($r('sys.color.white'))
        .textAlign(TextAlign.Center)
      Row({ space: $r('app.float.space_s') }) {
        Button($r('app.string.action_retry'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontColor($r('sys.color.white'))
          .onClick(() => this.retryPlayback())
        Button($r('app.string.action_open_browser'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontColor($r('sys.color.white'))
          .onClick(() => this.openVideoLink())
      }
    }
    .padding($r('app.float.space_m'))
    .backgroundColor($r('app.color.hm_scrim'))
    .borderRadius($r('app.float.radius_small'))
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Up) {
        event.stopPropagation();
      }
    })
  }

  @Builder
  FullscreenContent(session: number) {
    Stack({ alignContent: Alignment.Center }) {
      Video({
        src: this.videoUrl,
        previewUri: this.posterUrl,
        controller: this.fullscreenController,
        currentProgressRate: this.videoPlaybackRate()
      })
        .width('100%')
        .height('100%')
        .autoPlay(false)
        .controls(false)
        .objectFit(ImageFit.Contain)
        .backgroundColor($r('app.color.hm_video_background'))
        .onPrepared((info: PreparedInfo) => this.onFullscreenPrepared(info, session))
        .onStart(() => this.onPlaybackStarted(true, session))
        .onPause(() => this.onPlaybackPaused(true, session))
        .onFinish(() => this.onPlaybackFinished(true, session))
        .onUpdate((info: PlaybackInfo) => this.onPlaybackUpdate(info, true, session))
        .onError(() => this.onPlaybackError(true, session))
      if (this.playerFailed) {
        this.PlaybackError()
      }
      if (this.controlsVisible) {
        this.ControlsOverlay(true)
      }
      if (this.mediaActions.busy()) {
        MediaActionOverlay({
          controller: this.mediaActions,
          onCancel: () => this.mediaActions.cancel()
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hm_video_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 2 })
          .onAction((_event: GestureEvent) => this.togglePlaybackFromDoubleTap()),
        TapGesture({ count: 1 })
          .onAction((_event: GestureEvent) => this.toggleControls())
      )
    )
  }

  @Builder
  FullscreenCover() {
    this.FullscreenContent(this.fullscreenViewSession)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Video({
        src: this.videoUrl,
        previewUri: this.posterUrl,
        controller: this.inlineController,
        currentProgressRate: this.videoPlaybackRate()
      })
        .width('100%')
        .height('100%')
        .autoPlay(false)
        .controls(false)
        .objectFit(ImageFit.Contain)
        .backgroundColor($r('app.color.hm_video_background'))
        .onPrepared((info: PreparedInfo) => this.onPrepared(info))
        .onStart(() => this.onPlaybackStarted(false))
        .onPause(() => this.onPlaybackPaused(false))
        .onFinish(() => this.onPlaybackFinished(false))
        .onUpdate((info: PlaybackInfo) => this.onPlaybackUpdate(info, false))
        .onError(() => this.onPlaybackError(false))
      if (this.playerFailed) {
        this.PlaybackError()
      }
      if (this.controlsVisible) {
        this.ControlsOverlay(false)
      }
      if (this.mediaActions.busy()) {
        MediaActionOverlay({
          controller: this.mediaActions,
          onCancel: () => this.mediaActions.cancel()
        })
      }
    }
    .width('100%')
    .height(this.playerHeight)
    .clip(true)
    .borderRadius(this.playerRadius)
    .backgroundColor($r('app.color.hm_video_background'))
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 2 })
          .onAction((_event: GestureEvent) => this.togglePlaybackFromDoubleTap()),
        TapGesture({ count: 1 })
          .onAction((_event: GestureEvent) => this.toggleControls())
      )
    )
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Up) {
        event.stopPropagation();
      }
    })
    .onVisibleAreaChange([0.0, 0.25], (isVisible: boolean, currentRatio: number) => {
      if (this.pauseWhenHidden && (!isVisible || currentRatio < 0.25)) {
        this.inlineController.pause();
      }
    })
    .bindContextMenu(this.VideoMenu(), ResponseType.LongPress)
    .bindContentCover($$this.fullscreenVisible, this.FullscreenCover, {
      modalTransition: ModalTransition.ALPHA,
      backgroundColor: $r('app.color.hm_video_background'),
      enableSafeArea: false,
      onWillAppear: () => this.onFullscreenCoverWillAppear(),
      onAppear: () => this.onFullscreenCoverAppeared(),
      onWillDisappear: () => this.beginFullscreenExit(),
      onDisappear: () => this.onFullscreenDisappeared()
    })
  }
}
