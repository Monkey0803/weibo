export class SocialEntityInteractionGuard {
  private active: boolean = false;
  private generation: number = 0;

  begin(): void {
    this.generation += 1;
    this.active = true;
  }

  end(): void {
    const generation: number = this.generation;
    setTimeout((): void => {
      if (this.generation === generation) {
        this.active = false;
      }
    }, 0);
  }

  blocked(): boolean {
    return this.active;
  }
}
