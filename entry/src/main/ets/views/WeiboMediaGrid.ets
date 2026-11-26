import { WeiboMediaTile } from './WeiboMediaTile';

@ComponentV2
export struct WeiboMediaGrid {
  @Param imageUrls: string[] = [];
  @Param gridHeight: Length = $r('app.float.media_grid_row_height');
  @Event onOpen: (imageIndex: number) => void = (imageIndex: number): void => {};

  build() {
    Grid() {
      ForEach(this.imageUrls, (imageUrl: string, imageIndex: number) => {
        if (imageIndex < 9) {
          GridItem() {
            if (imageIndex === 8 && this.imageUrls.length > 9) {
              WeiboMediaTile({
                imageUrl: imageUrl,
                imageIndex: imageIndex,
                remainingCount: this.imageUrls.length - 9,
                onOpen: (selectedIndex: number) => this.onOpen(selectedIndex)
              })
            } else {
              WeiboMediaTile({
                imageUrl: imageUrl,
                imageIndex: imageIndex,
                onOpen: (selectedIndex: number) => this.onOpen(selectedIndex)
              })
            }
          }
        }
      }, (imageUrl: string, imageIndex: number) => imageUrl + imageIndex.toString())
    }
    .width('100%')
    .height(this.gridHeight)
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap($r('app.float.media_grid_gap'))
    .rowsGap($r('app.float.media_grid_gap'))
    .scrollBar(BarState.Off)
  }
}
