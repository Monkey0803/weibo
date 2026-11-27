import { ApiFailureKind, Result, WeiboPost } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class ComposeViewModel {
  @Trace text: string = '';
  @Trace sending: boolean = false;
  @Trace errorMessage: string = '';
  @Trace failureKind: ApiFailureKind = ApiFailureKind.NONE;

  canSend(): boolean {
    const length: number = this.text.trim().length;
    return length > 0 && length <= 2000 && !this.sending;
  }

  async send(): Promise<Result<WeiboPost>> {
    if (!this.canSend()) {
      return Result.fail<WeiboPost>('');
    }
    this.sending = true;
    const result: Result<WeiboPost> = await weiboRepository.publish(this.text.trim());
    this.sending = false;
    if (result.success) {
      this.text = '';
    } else {
      this.errorMessage = result.message;
      this.failureKind = result.failureKind;
    }
    return result;
  }
}
