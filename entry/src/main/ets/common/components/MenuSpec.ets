/** 一条菜单项。id 在同一张菜单中必须唯一。 */
export class MenuItemSpec {
  readonly id: string;
  readonly label: ResourceStr;
  readonly action: () => void;
  icon: Resource | undefined = undefined;
  selected: boolean = false;
  danger: boolean = false;
  itemEnabled: boolean = true;

  constructor(id: string, label: ResourceStr, action: () => void) {
    this.id = id;
    this.label = label;
    this.action = action;
  }

  withIcon(icon: Resource): MenuItemSpec {
    this.icon = icon;
    return this;
  }

  markSelected(): MenuItemSpec {
    this.selected = true;
    return this;
  }

  markDanger(): MenuItemSpec {
    this.danger = true;
    return this;
  }

  withEnabled(itemEnabled: boolean): MenuItemSpec {
    this.itemEnabled = itemEnabled;
    return this;
  }

  key(): string {
    return this.id;
  }
}

/** 菜单分区；header 为空时只显示分隔线。 */
export class MenuSectionSpec {
  readonly items: MenuItemSpec[];
  readonly header: ResourceStr | undefined;

  constructor(items: MenuItemSpec[], header?: ResourceStr) {
    this.items = items;
    this.header = header;
  }
}

/** AppMenu 的纯数据规格。 */
export class MenuSpec {
  readonly sections: MenuSectionSpec[];
  readonly menuWidth: Length | undefined;

  constructor(sections: MenuSectionSpec[], menuWidth?: Length) {
    this.sections = sections;
    this.menuWidth = menuWidth;
  }

  static fromItems(items: MenuItemSpec[]): MenuSpec {
    return new MenuSpec([new MenuSectionSpec(items)]);
  }

  static fromSections(sections: MenuSectionSpec[]): MenuSpec {
    return new MenuSpec(sections);
  }

  firstSelectedId(): string {
    for (let sectionIndex: number = 0; sectionIndex < this.sections.length; sectionIndex += 1) {
      const items: MenuItemSpec[] = this.sections[sectionIndex].items;
      for (let itemIndex: number = 0; itemIndex < items.length; itemIndex += 1) {
        if (items[itemIndex].selected) {
          return items[itemIndex].id;
        }
      }
    }
    return '';
  }

  hasUniqueKeys(): boolean {
    const known: Set<string> = new Set<string>();
    for (let sectionIndex: number = 0; sectionIndex < this.sections.length; sectionIndex += 1) {
      const items: MenuItemSpec[] = this.sections[sectionIndex].items;
      for (let itemIndex: number = 0; itemIndex < items.length; itemIndex += 1) {
        if (known.has(items[itemIndex].id)) {
          return false;
        }
        known.add(items[itemIndex].id);
      }
    }
    return true;
  }
}
