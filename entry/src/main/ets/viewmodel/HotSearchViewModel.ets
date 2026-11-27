import { LoadState, Result, WeiboHotTopic } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

@ObservedV2
export class HotSearchViewModel {
  @Trace topics: WeiboHotTopic[] = [];
  @Trace state: LoadState = LoadState.IDLE;
  @Trace errorMessage: string = '';

  async load(): Promise<void> {
    this.state = LoadState.LOADING;
    this.errorMessage = '';
    const result: Result<WeiboHotTopic[]> = await weiboRepository.hotTopics();
    if (result.success && result.data) {
      this.topics = result.data;
      this.state = this.topics.length > 0 ? LoadState.READY : LoadState.EMPTY;
    } else {
      this.errorMessage = result.message;
      this.state = LoadState.ERROR;
    }
  }
}
