import { ApiFailureKind, LoadState, Result, SessionInfo } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';
import { WeiboSession } from '../service/WeiboSession';

@ObservedV2
export class AuthViewModel {
  @Trace loggedIn: boolean = false;
  @Trace userId: string = '';
  @Trace state: LoadState = LoadState.IDLE;
  @Trace errorMessage: string = '';
  @Trace failureKind: ApiFailureKind = ApiFailureKind.NONE;

  async refresh(): Promise<void> {
    this.state = LoadState.LOADING;
    this.errorMessage = '';
    this.failureKind = ApiFailureKind.NONE;
    const result: Result<SessionInfo> = await weiboRepository.session();
    if (result.success && result.data) {
      this.loggedIn = result.data.loggedIn;
      this.userId = result.data.userId;
      this.state = LoadState.READY;
    } else {
      this.errorMessage = result.message;
      this.failureKind = result.failureKind;
      this.state = LoadState.ERROR;
    }
  }

  async logout(): Promise<boolean> {
    if (!await WeiboSession.clear()) {
      return false;
    }
    this.loggedIn = false;
    this.userId = '';
    this.state = LoadState.READY;
    this.errorMessage = '';
    this.failureKind = ApiFailureKind.NONE;
    return true;
  }
}

export const authViewModel: AuthViewModel = new AuthViewModel();
