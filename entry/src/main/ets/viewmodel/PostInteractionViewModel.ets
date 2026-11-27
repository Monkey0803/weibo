import { Result, WeiboPost } from '../model/WeiboModels';
import { weiboRepository } from '../service/WeiboRepository';

class PostInteractionState {
  readonly postId: string;
  liked: boolean;
  likesCount: number;
  repostsCount: number;
  favorited: boolean;
  deleted: boolean = false;

  constructor(post: WeiboPost) {
    this.postId = post.id;
    this.liked = post.liked;
    this.likesCount = post.likesCount;
    this.repostsCount = post.repostsCount;
    this.favorited = post.favorited;
  }
}

@ObservedV2
export class PostInteractionViewModel {
  @Trace revision: number = 0;
  @Trace pendingPostIds: string[] = [];
  private states: PostInteractionState[] = [];

  remember(post: WeiboPost): void {
    if (post.id.length === 0 || this.find(post.id) >= 0) {
      return;
    }
    this.states.push(new PostInteractionState(post));
    this.revision += 1;
  }

  liked(post: WeiboPost): boolean {
    const index: number = this.findObserved(post.id);
    return index >= 0 ? this.states[index].liked : post.liked;
  }

  likesCount(post: WeiboPost): number {
    const index: number = this.findObserved(post.id);
    return index >= 0 ? this.states[index].likesCount : post.likesCount;
  }

  repostsCount(post: WeiboPost): number {
    const index: number = this.findObserved(post.id);
    return index >= 0 ? this.states[index].repostsCount : post.repostsCount;
  }

  favorited(post: WeiboPost): boolean {
    const index: number = this.findObserved(post.id);
    return index >= 0 ? this.states[index].favorited : post.favorited;
  }

  deleted(post: WeiboPost): boolean {
    const index: number = this.findObserved(post.id);
    return index >= 0 && this.states[index].deleted;
  }

  pending(postId: string): boolean {
    this.revision;
    return this.pendingPostIds.includes(postId);
  }

  async toggleLike(post: WeiboPost): Promise<Result<boolean>> {
    this.remember(post);
    if (!this.begin(post.id)) {
      return Result.fail<boolean>('');
    }
    try {
      const liked: boolean = this.liked(post);
      const result: Result<boolean> = await weiboRepository.like(post.id, liked);
      if (!result.success) {
        return result;
      }
      const index: number = this.find(post.id);
      if (index >= 0) {
        this.states[index].liked = !liked;
        this.states[index].likesCount = Math.max(0, this.states[index].likesCount + (liked ? -1 : 1));
        this.revision += 1;
      }
      return Result.ok<boolean>(true);
    } finally {
      this.end(post.id);
    }
  }

  clear(): void {
    this.states = [];
    this.pendingPostIds = [];
    this.revision += 1;
  }

  async repost(post: WeiboPost, content: string): Promise<boolean> {
    this.remember(post);
    if (!this.begin(post.id)) {
      return false;
    }
    try {
      const result: Result<boolean> = await weiboRepository.repost(post.id, post.mid, content.trim());
      if (!result.success) {
        return false;
      }
      const index: number = this.find(post.id);
      if (index >= 0) {
        this.states[index].repostsCount += 1;
        this.revision += 1;
      }
      return true;
    } finally {
      this.end(post.id);
    }
  }

  async toggleFavorite(post: WeiboPost): Promise<Result<boolean>> {
    this.remember(post);
    if (!this.begin(post.id)) {
      return Result.fail<boolean>('');
    }
    try {
      const favorited: boolean = this.favorited(post);
      const result: Result<boolean> = await weiboRepository.favorite(post.id, favorited);
      if (result.success) {
        const index: number = this.find(post.id);
        if (index >= 0) {
          this.states[index].favorited = !favorited;
          this.revision += 1;
        }
      }
      return result;
    } finally {
      this.end(post.id);
    }
  }

  async deletePost(post: WeiboPost): Promise<Result<boolean>> {
    this.remember(post);
    if (!this.begin(post.id)) {
      return Result.fail<boolean>('');
    }
    try {
      const result: Result<boolean> = await weiboRepository.deletePost(post.id, post.mid);
      if (result.success) {
        const index: number = this.find(post.id);
        if (index >= 0) {
          this.states[index].deleted = true;
          this.revision += 1;
        }
      }
      return result;
    } finally {
      this.end(post.id);
    }
  }

  private begin(postId: string): boolean {
    if (this.pendingPostIds.includes(postId)) {
      return false;
    }
    this.pendingPostIds = this.pendingPostIds.concat([postId]);
    this.revision += 1;
    return true;
  }

  private end(postId: string): void {
    this.pendingPostIds = this.pendingPostIds.filter((item: string) => item !== postId);
    this.revision += 1;
  }

  private findObserved(postId: string): number {
    this.revision;
    return this.find(postId);
  }

  private find(postId: string): number {
    for (let i: number = 0; i < this.states.length; i += 1) {
      if (this.states[i].postId === postId) {
        return i;
      }
    }
    return -1;
  }
}

export const postInteractionViewModel: PostInteractionViewModel = new PostInteractionViewModel();
