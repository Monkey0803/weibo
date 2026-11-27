import { LoadState, Result, SocialListKind, SocialListRouteParam, SocialTextEntity,
  WeiboPost } from '../model/WeiboModels';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';
import { WeiboPostCard } from './WeiboPostCard';
import { ProfileMenuButton } from './ProfileMenuButton';
import { RouterConstants } from '../common/constants/RouterConstants';
import { authViewModel } from '../viewmodel/AuthViewModel';
import { notificationService } from '../service/NotificationService';
import { ThemeColorController } from '../service/ThemeColorController';
import { BreakpointConstants } from '../common/constants/BreakpointConstants';
import { SocialRichText } from '../common/components/SocialRichText';
import { socialEntityActionService } from '../service/SocialEntityActionService';
import { common } from '@kit.AbilityKit';

@ComponentV2
export struct ProfileContent {
  @Param viewModel: ProfileViewModel = new ProfileViewModel();
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Param showHeader: boolean = true;
  @Local detailsExpanded: boolean = false;

  private openSocial(kind: SocialListKind): void {
    const title: ResourceStr = kind === SocialListKind.FOLLOWING ?
      $r('app.string.following_title') : $r('app.string.followers_title');
    this.navPathStack.pushPath(new NavPathInfo(RouterConstants.PAGE_SOCIAL_LIST,
      new SocialListRouteParam(this.viewModel.user.id, kind, title)));
  }

  private openEntity(entity: SocialTextEntity): void {
    const hostContext: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    socialEntityActionService.open(entity, this.navPathStack, hostContext, this.getUIContext());
  }

  private async toggleFollow(): Promise<void> {
    const result: Result<boolean> = await this.viewModel.toggleFollow();
    if (!result.success) {
      notificationService.showError(this.getUIContext(), $r('app.string.mutation_failed'));
    }
  }

  @Builder
  profileStat(count: number, label: ResourceStr, kind: number) {
    Column({ space: $r('app.float.space_xxs') }) {
      Text(count.toString())
        .fontSize($r('app.float.font_size_title'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.hm_text_primary'))
      Text(label)
        .fontSize($r('app.float.font_size_metric'))
        .fontColor($r('app.color.hm_text_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (kind === SocialListKind.FOLLOWING || kind === SocialListKind.FOLLOWERS) {
        this.openSocial(kind);
      }
    })
  }

  @Builder
  profileStats() {
    Row() {
      this.profileStat(this.viewModel.user.followingCount, $r('app.string.profile_following_label'),
        SocialListKind.FOLLOWING)
      this.profileStat(this.viewModel.user.followersCount, $r('app.string.profile_followers_label'),
        SocialListKind.FOLLOWERS)
      this.profileStat(this.viewModel.user.statusesCount, $r('app.string.profile_posts_label'), -1)
    }
    .width('100%')
    .height($r('app.float.button_height'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  detailRow(label: ResourceStr, value: string) {
    Row({ space: $r('app.float.space_m') }) {
      Text(label)
        .width($r('app.float.profile_detail_label_width'))
        .fontSize($r('app.float.font_size_caption'))
        .fontColor($r('app.color.hm_text_secondary'))
      Text(value)
        .layoutWeight(1)
        .fontSize($r('app.float.font_size_caption'))
        .fontColor($r('app.color.hm_text_primary'))
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  profileHeader() {
    Column({ space: $r('app.float.space_s') }) {
      if (this.viewModel.user.description.length > 0) {
        SocialRichText({
          text: this.viewModel.user.description,
          entities: this.viewModel.user.descriptionEntities,
          fontSize: $r('app.float.font_size_caption'),
          fontColor: $r('app.color.hm_text_secondary'),
          maxLines: 2,
          brandColor: ThemeColorController.brand(),
          pressedColor: ThemeColorController.brandPressed(),
          onEntityTap: (entity: SocialTextEntity) => this.openEntity(entity)
        })
      }

      if (authViewModel.loggedIn && this.viewModel.user.id !== authViewModel.userId) {
        GridRow({
          columns: BreakpointConstants.GRID_COLUMNS,
          gutter: { x: $r('app.float.space_s'), y: $r('app.float.space_s') },
          breakpoints: {
            value: BreakpointConstants.PROFILE_HEADER_BREAKPOINTS,
            reference: BreakpointsReference.ComponentSize
          }
        }) {
          GridCol({ span: { xs: 12, sm: 6 } }) {
            this.profileStats()
          }
          GridCol({ span: { xs: 10, sm: 4 } }) {
            Row() {
              Button(this.viewModel.user.following ? $r('app.string.action_unfollow') :
                $r('app.string.action_follow'))
                .width($r('app.float.profile_follow_button_width'))
                .height($r('app.float.button_height'))
                .fontColor(this.viewModel.user.following ? ThemeColorController.brand() : $r('sys.color.white'))
                .backgroundColor(this.viewModel.user.following ? ThemeColorController.soft() :
                  ThemeColorController.brand())
                .enabled(!this.viewModel.followPending)
                .onClick(() => this.toggleFollow())
            }
            .width('100%')
            .height($r('app.float.button_height'))
            .justifyContent(FlexAlign.Center)
          }
          GridCol({ span: { xs: 2, sm: 2 } }) {
            Row() {
              ProfileMenuButton({ user: this.viewModel.user })
            }
            .width('100%')
            .height($r('app.float.button_height'))
            .justifyContent(FlexAlign.End)
          }
        }
        .width('100%')
      } else {
        Row({ space: $r('app.float.space_s') }) {
          this.profileStats()
          ProfileMenuButton({ user: this.viewModel.user })
        }
        .width('100%')
      }

      if (this.viewModel.user.verifiedReason.length > 0 || this.viewModel.user.ipLocation.length > 0 ||
        this.viewModel.user.location.length > 0 || this.viewModel.user.birthday.length > 0 ||
        this.viewModel.user.joinedAt.length > 0) {
        Row({ space: $r('app.float.space_s') }) {
          if (this.viewModel.user.verifiedReason.length > 0) {
            Text(this.viewModel.user.verifiedReason)
              .layoutWeight(1)
              .fontSize($r('app.float.font_size_metric'))
              .fontColor(ThemeColorController.brand())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'),
                top: $r('app.float.space_s'), bottom: $r('app.float.space_s') })
              .backgroundColor(ThemeColorController.soft())
              .borderRadius($r('app.float.radius_small'))
          }
          if (this.viewModel.user.ipLocation.length > 0) {
            Text(this.viewModel.user.ipLocation)
              .layoutWeight(1)
              .fontSize($r('app.float.font_size_metric'))
              .fontColor($r('app.color.hm_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'),
                top: $r('app.float.space_s'), bottom: $r('app.float.space_s') })
              .backgroundColor($r('app.color.hm_page_transparent'))
              .border({ width: $r('app.float.stroke_width'), color: $r('app.color.hm_divider') })
              .borderRadius($r('app.float.radius_small'))
          }
          if (this.viewModel.user.location.length > 0 || this.viewModel.user.birthday.length > 0 ||
            this.viewModel.user.joinedAt.length > 0) {
            Button(this.detailsExpanded ? $r('app.string.profile_details_collapse') :
              $r('app.string.profile_details_expand'))
              .buttonStyle(ButtonStyleMode.TEXTUAL)
              .fontColor(ThemeColorController.brand())
              .onClick(() => this.detailsExpanded = !this.detailsExpanded)
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        if (this.detailsExpanded) {
          Column({ space: $r('app.float.space_m') }) {
            if (this.viewModel.user.location.length > 0) {
              this.detailRow($r('app.string.profile_location_label'), this.viewModel.user.location)
            }
            if (this.viewModel.user.birthday.length > 0) {
              this.detailRow($r('app.string.profile_birthday_label'), this.viewModel.user.birthday)
            }
            if (this.viewModel.user.joinedAt.length > 0) {
              this.detailRow($r('app.string.profile_joined_label'), this.viewModel.user.joinedAt)
            }
          }
          .width('100%')
          .padding({ top: $r('app.float.space_s') })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding($r('app.float.space_m'))
    .backgroundColor($r('app.color.hm_card_background'))
    .borderRadius($r('app.float.radius_card'))
  }

  build() {
    Column({ space: $r('app.float.space_m') }) {
      if (this.viewModel.profileState === LoadState.LOADING && this.viewModel.posts.length === 0) {
        LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size'))
      }
      if (this.viewModel.profileState === LoadState.ERROR) {
        if (this.viewModel.errorMessage.length > 0) {
          Text(this.viewModel.errorMessage).fontColor($r('app.color.hm_error'))
        } else {
          Text($r('app.string.error_api_unavailable')).fontColor($r('app.color.hm_error'))
        }
        Button($r('app.string.action_retry'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => this.viewModel.retry())
      } else if (this.showHeader && this.viewModel.profileState === LoadState.READY) {
        this.profileHeader()
      }
      if (this.viewModel.postsState === LoadState.EMPTY) {
        Text($r('app.string.empty_profile_posts'))
          .fontColor($r('app.color.hm_text_secondary'))
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding($r('app.float.space_xl'))
      } else if (this.viewModel.postsState === LoadState.ERROR) {
        Text(this.viewModel.postsErrorMessage.length > 0
          ? this.viewModel.postsErrorMessage : $r('app.string.error_api_unavailable'))
          .fontColor($r('app.color.hm_error'))
        Button($r('app.string.action_retry'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => this.viewModel.retry())
      }
      ForEach(this.viewModel.posts, (post: WeiboPost) => {
        WeiboPostCard({ post: post, navPathStack: this.navPathStack })
      }, (post: WeiboPost) => post.id)
      if (this.viewModel.loadingMore) {
        Row({ space: $r('app.float.space_s') }) {
          LoadingProgress().width($r('app.float.progress_size')).height($r('app.float.progress_size'))
          Text($r('app.string.loading_more')).fontColor($r('app.color.hm_text_secondary'))
        }.width('100%').justifyContent(FlexAlign.Center).padding($r('app.float.space_m'))
      } else if (this.viewModel.loadMoreFailed) {
        Column({ space: $r('app.float.space_s') }) {
          Text(this.viewModel.loadMoreErrorMessage.length > 0
            ? this.viewModel.loadMoreErrorMessage : $r('app.string.error_api_unavailable'))
            .fontColor($r('app.color.hm_error'))
            .textAlign(TextAlign.Center)
          Button($r('app.string.action_retry'))
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .onClick(() => this.viewModel.loadMore())
        }.width('100%').padding($r('app.float.space_m'))
      } else if (this.viewModel.hasMore) {
        Button($r('app.string.action_load_more'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .width('100%')
          .onClick(() => this.viewModel.loadMore())
      }
    }.width('100%')
  }
}
