import { LoadState, Result, SessionInfo } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class AuthViewModel {
  @Trace loggedIn: boolean = false;
  @Trace userId: string = '';
  @Trace state: LoadState = LoadState.IDLE;

  async refresh(): Promise<void> {
    this.state = LoadState.LOADING;
    const result: Result<SessionInfo> = await weiboRepository.session();
    if (result.success && result.data) {
      this.loggedIn = result.data.loggedIn;
      this.userId = result.data.userId;
      this.state = LoadState.READY;
    } else {
      this.loggedIn = false;
      this.userId = '';
      this.state = LoadState.ERROR;
    }
  }
}

export const authViewModel: AuthViewModel = new AuthViewModel();
