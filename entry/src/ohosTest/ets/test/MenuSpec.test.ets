import { describe, it, expect } from '@ohos/hypium';
import { MenuItemSpec, MenuSectionSpec, MenuSpec } from '../../../main/ets/common/components/MenuSpec';

function emptyAction(): void {
}

export default function menuSpecTest() {
  describe('MenuSpec', () => {
    it('finds_selected_item_across_sections', 0, () => {
      const spec: MenuSpec = MenuSpec.fromSections([
        new MenuSectionSpec([new MenuItemSpec('copy', 'Copy', emptyAction)]),
        new MenuSectionSpec([new MenuItemSpec('share', 'Share', emptyAction).markSelected()])
      ]);
      expect(spec.firstSelectedId()).assertEqual('share');
    });

    it('requires_unique_item_keys_across_sections', 0, () => {
      const valid: MenuSpec = MenuSpec.fromItems([
        new MenuItemSpec('copy', 'Copy', emptyAction),
        new MenuItemSpec('share', 'Share', emptyAction)
      ]);
      const duplicate: MenuSpec = MenuSpec.fromSections([
        new MenuSectionSpec([new MenuItemSpec('copy', 'Copy', emptyAction)]),
        new MenuSectionSpec([new MenuItemSpec('copy', 'Copy again', emptyAction)])
      ]);
      expect(valid.hasUniqueKeys()).assertTrue();
      expect(duplicate.hasUniqueKeys()).assertFalse();
    });
  });
}
