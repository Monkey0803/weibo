class InlineVideoEntry {
  readonly controller: VideoController;

  constructor(controller: VideoController) {
    this.controller = controller;
  }
}

export class InlineVideoCoordinator {
  private entries: InlineVideoEntry[] = [];

  register(controller: VideoController): void {
    if (this.find(controller) >= 0) {
      return;
    }
    this.entries.push(new InlineVideoEntry(controller));
  }

  unregister(controller: VideoController): void {
    this.entries = this.entries.filter((entry: InlineVideoEntry) => entry.controller !== controller);
  }

  activate(controller: VideoController): void {
    this.entries.forEach((entry: InlineVideoEntry) => {
      if (entry.controller !== controller) {
        entry.controller.pause();
      }
    });
  }

  private find(controller: VideoController): number {
    for (let index: number = 0; index < this.entries.length; index += 1) {
      if (this.entries[index].controller === controller) {
        return index;
      }
    }
    return -1;
  }
}

export const inlineVideoCoordinator: InlineVideoCoordinator = new InlineVideoCoordinator();
