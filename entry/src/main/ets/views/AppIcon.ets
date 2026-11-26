@ComponentV2
export struct AppIcon {
  @Param source: Resource = $r('app.media.icon_ripple_chat');
  @Param iconSize: Resource = $r('app.float.icon_size');
  @Param tint: ResourceColor = $r('app.color.hm_text_primary');

  build() {
    Image(this.source)
      .width(this.iconSize)
      .height(this.iconSize)
      .objectFit(ImageFit.Contain)
      .fillColor(this.tint)
      .accessibilityLevel('no')
  }
}
