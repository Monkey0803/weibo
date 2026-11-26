/*
 * MaterialController.ets — 沉浸光感材质（hdsMaterial + uiMaterial）。
 *
 * 两个层次：
 * 1) HDS 材质（hdsMaterial，6.1.0(23)+，手机 / 平板）：只表达"材质类型 + 四档厚薄"，
 *    交给 HdsNavigation / HdsTabs 的 systemMaterialEffect，形状是 SystemMaterialParams。
 *    调 getSystemMaterialTypes() 前必须 try/catch —— 不支持时它会抛 801，而不是返回空数组。
 * 2) 组件级沉浸系统材质（uiMaterial，26.0.0+）：形状是 ImmersiveMaterial 对象，挂到通用属性
 *    `.systemMaterial(...)`（或菜单 / 弹窗 options 的 systemMaterial 字段）。本文件的
 *    glassMaterial() / glassInteractiveMaterial() / menuOptions() 是**唯一**构造它的地方：
 *    默认**不设置 materialColor**（无底色 = 最通透），需要品牌色调时再显式传半透明字面量。
 *    注意 materialColor 是**加法**（叠一层纯色），不是"关闭自适应"的开关。
 *
 * 生效区域（华为文档 §8.1 / §10，强制）：普通组件只在 Navigation/NavDestination 标题栏、或
 * barPosition=End 的底部 TabBar 内生效；弹窗类组件 / 接口、菜单、Slider、Toggle、Select 全页面生效；
 * 其余区域（包括页面内容区）设置后**没有任何视觉效果**，且不会报错。
 *
 * 应用级开关：entry 模块 module.json5 的 metadata `ohos.arkui.UIMaterial.state`
 * （default / enable / disable）。ENABLE 会让系统清单内的组件默认获得材质（Dialog / Toast / 菜单 /
 * Toggle / Slider / Select / Chip / SegmentButton / Navigation 等自动接管样式；Popup / Tips / Button
 * 不在清单内，必须组件级显式设置），DISABLE 则让所有组件级材质设置彻底失效。组件级优先级高于应用级，
 * 但"关闭"必须用 uiMaterial.Material.empty，传 undefined 只是"恢复默认"，在 ENABLE 下反而会把默认
 * 材质放回来。
 *
 * 材质等级：uiMaterial 的 MaterialLevel 只有 EXQUISITE(0)/GENTLE(1)/SMOOTH(2) 三档，由设备算力
 * 决定、**只能查不能设**；hdsMaterial 另有 ADAPTIVE(10) 档，可设但低算力设备上设高等级会卡顿发热，
 * 所以这里对 hdsMaterial 的等级做了收敛（见 params()）。
 */

import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';
import { uiMaterial } from '@kit.ArkUI';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { MaterialKind, MaterialGrade } from '../common/constants/SettingsConstants';

export class MaterialController {
  private static cachedTypes: hdsMaterial.MaterialType[] | undefined = undefined;
  private static cachedGlassSupported: boolean | undefined = undefined;
  private static cachedGlassMaterial: uiMaterial.Material | undefined = undefined;
  private static cachedState: uiMaterial.MaterialState | undefined = undefined;
  private static cachedLevel: uiMaterial.MaterialLevel | undefined = undefined;

  /** 设备支持的 HDS 材质类型；不支持时返回空数组（并缓存，避免反复探测）。 */
  static supportedTypes(): hdsMaterial.MaterialType[] {
    const cached: hdsMaterial.MaterialType[] | undefined = MaterialController.cachedTypes;
    if (cached !== undefined) {
      return cached;
    }
    let types: hdsMaterial.MaterialType[] = [];
    try {
      types = hdsMaterial.getSystemMaterialTypes();
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('hdsMaterial.getSystemMaterialTypes failed: ' + error.code.toString());
      types = [];
    }
    MaterialController.cachedTypes = types;
    return types;
  }

  /** 设备是否支持 HDS 沉浸式材质（标题栏 / 页签的 systemMaterialEffect）。 */
  static immersiveSupported(): boolean {
    return MaterialController.supportedTypes().indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
  }

  /**
   * 应用级（全局）沉浸光感状态：module.json5 metadata `ohos.arkui.UIMaterial.state` 的运行时读法。
   *
   * 三态语义（不是布尔）：
   * - DEFAULT(0)：未配置，或显式配置 default —— 只有 Dialog / Toast / AlphabetIndexer / Text 文本菜单
   *   在组件自身没设背景、模糊、阴影时默认开启；
   * - ENABLE(1)：系统清单内的组件默认开启（Dialog / Toast / 菜单 / Chip / Select / Toggle / Slider /
   *   SegmentButton / Navigation / NavDestination …；页签栏在悬浮样式生效时才算），且材质优先级高于
   *   组件自身的背景色 / 模糊 / 阴影 / 边框 —— 不需要再逐个挂材质，只想关掉其中某个时才用
   *   Material.empty。**Popup / Tips / Button 不在清单内**，ENABLE 下仍需组件级显式设置；
   * - DISABLE(2)：所有组件级材质设置一律不生效。
   *
   * 该接口 26.0.0 起才有，且只在 **entry** 模块的配置会被读取；低版本 / 异常一律兜底成 DEFAULT。
   */
  static materialState(): uiMaterial.MaterialState {
    const cached: uiMaterial.MaterialState | undefined = MaterialController.cachedState;
    if (cached !== undefined) {
      return cached;
    }
    let state: uiMaterial.MaterialState = uiMaterial.MaterialState.DEFAULT;
    try {
      const info: uiMaterial.MaterialInfo = uiMaterial.getMaterialInfo();
      state = info.state;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('uiMaterial.getMaterialInfo failed: ' + error.code.toString());
      state = uiMaterial.MaterialState.DEFAULT;
    }
    MaterialController.cachedState = state;
    return state;
  }

  /** 应用级是否没被显式禁用（DEFAULT / ENABLE 都算"可开"）。 */
  static appMaterialOn(): boolean {
    return MaterialController.materialState() !== uiMaterial.MaterialState.DISABLE;
  }

  /** HDS 轨道（HdsTabs / HdsNavigation）当前是否真的会渲染材质。 */
  static immersiveActive(immersiveOn: boolean): boolean {
    return immersiveOn && MaterialController.immersiveSupported() && MaterialController.appMaterialOn();
  }

  /**
   * 全局材质等级 = 设备算力档（高 / 中 / 低）。
   *
   * 强制规则（华为文档 §5.2）：只有 `isImmersiveMaterialSupported()` 为 true 才有必要查询；
   * 该值由设备定义、应用运行后不变，**没有任何设置入口**（不存在 setMaterialLevel 之类 API），
   * 所以只缓存查询结果，不做任何"写入"。
   *
   * 查不到时（低版本 / 异常）按最低算力 SMOOTH 处理：宁可让 hdsMaterial 退回 ADAPTIVE，
   * 也不在高等级上冒险。
   */
  static globalLevel(): uiMaterial.MaterialLevel {
    const cached: uiMaterial.MaterialLevel | undefined = MaterialController.cachedLevel;
    if (cached !== undefined) {
      return cached;
    }
    let level: uiMaterial.MaterialLevel = uiMaterial.MaterialLevel.SMOOTH;
    if (MaterialController.glassSupported()) {
      try {
        level = uiMaterial.getGlobalMaterialLevel();
      } catch (err) {
        const error: BusinessError = err as BusinessError;
        console.error('uiMaterial.getGlobalMaterialLevel failed: ' + error.code.toString());
        level = uiMaterial.MaterialLevel.SMOOTH;
      }
    }
    MaterialController.cachedLevel = level;
    return level;
  }

  /** 设备是否低算力（材质只有简化的背景色 / 边框 / 阴影实现）。 */
  static lowCompute(): boolean {
    return MaterialController.globalLevel() === uiMaterial.MaterialLevel.SMOOTH;
  }

  /** 组件级材质此刻是否**有意义**：设备支持，且应用级没被 DISABLE 掉。 */
  static materialUsable(): boolean {
    return MaterialController.glassSupported() && MaterialController.appMaterialOn();
  }

  /**
   * 组件级沉浸系统材质（uiMaterial）是否可用：26.0.0+ 且设备支持。
   *
   * 文档要求挂载 systemMaterial 之前必须调用 isImmersiveMaterialSupported()；该接口本身就是
   * 26.0.0 起才有，低版本直接调用会抛异常，所以先用 apiAvailable('26.0.0') 挡一层，
   * 外层再 try/catch 兜底。结果与构造出的材质一起缓存，避免每次 build 都探测 / 重建。
   */
  static glassSupported(): boolean {
    const cached: boolean | undefined = MaterialController.cachedGlassSupported;
    if (cached !== undefined) {
      return cached;
    }
    let supported: boolean = false;
    try {
      supported = deviceInfo.apiAvailable('26.0.0') && uiMaterial.isImmersiveMaterialSupported();
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('uiMaterial.isImmersiveMaterialSupported failed: ' + error.code.toString());
      supported = false;
    }
    MaterialController.cachedGlassSupported = supported;
    return supported;
  }

  /**
   * 玻璃材质：最通透配方（无底色 + ULTRA_THIN）+ 智能反色 + 材质自带阴影。
   *
   * 为什么这样配：
   * - 不设 materialColor → 不在滤镜上叠任何纯色，壁纸透出最多；
   * - ULTRA_THIN → 滤镜最薄；colorInvert 也只在 ULTRA_THIN / THIN 这类薄材质上生效；
   * - 若产品要品牌色调，再显式传**半透明字面量**（如 '#33FFFFFF'）：materialColor 是加法，
   *   会多一层底色、通透度下降；传 $r('sys.color.*') / $r('app.color.*') 还会让底色随深浅色变化。
   *
   * 其余硬性要求：
   * - 若加了颜色，必须半透明 —— 纯不透明会遮挡滤镜 / 折射 / 高光；
   * - colorInvert: true —— 深色壁纸上前景仍可读（**前景文字必须是 $r('sys.color.*') 这类
   *   特殊系统资源色**，硬编码颜色不会触发反色）；
   * - 不设 materialColor 时不要再给同一组件设 backgroundColor：高 / 中算力下 systemMaterial
   *   生效时 backgroundColor 会被重置为透明，二者会打架。
   *
   * @param enabled 总开关（appSettings.immersiveOn）。关掉时返回 uiMaterial.Material.empty
   *                （**显式关闭**默认材质）；设备不支持 / 应用级 DISABLE 时返回 undefined，
   *                组件退回自身已设置的通用属性样式（文档 §7 的降级方式）。
   */
  static glassMaterial(enabled: boolean): uiMaterial.Material | undefined {
    if (!MaterialController.materialUsable()) {
      // 设备不支持 / 应用级 DISABLE：不挂材质，组件回到自己设置的通用属性样式。
      return undefined;
    }
    if (!enabled) {
      // 用户关掉了沉浸光感：必须用 Material.empty **显式关闭**。
      // 传 undefined 只是"恢复默认"，应用级 ENABLE 下会把默认材质放回来（文档 §11.5 / Q2）。
      return uiMaterial.Material.empty;
    }
    const cached: uiMaterial.Material | undefined = MaterialController.cachedGlassMaterial;
    if (cached !== undefined) {
      return cached;
    }
    try {
      const options: uiMaterial.ImmersiveOptions = {
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        colorInvert: true,
        applyShadow: true
      };
      const material: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(options);
      MaterialController.cachedGlassMaterial = material;
      return material;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('uiMaterial.ImmersiveMaterial (glass) failed: ' + error.code.toString());
      return undefined;
    }
  }

  /**
   * 通透玻璃 + 光感交互反馈：在 glassMaterial() 之上加 interactive（按压缩放形变）与
   * lightEffect（触摸处的光斑跟随）。
   *
   * 用在底部 TabBar 内的悬浮 MiniBar 上（沉浸式迷你栏）。lightEffect 同样只在高 / 中算力设备
   * 上有反馈，其余设备静默降级，不需要额外分支。
   */
  static glassInteractiveMaterial(enabled: boolean, lightEnabled: boolean): uiMaterial.Material | undefined {
    if (!MaterialController.materialUsable()) {
      return undefined;
    }
    if (!enabled) {
      return uiMaterial.Material.empty;
    }
    if (!lightEnabled) {
      // 光感反馈关掉：就是普通透通玻璃（复用同一个缓存材质）。
      return MaterialController.glassMaterial(true);
    }
    try {
      const light: uiMaterial.LightEffectOptions = { color: $r('app.color.hm_brand') };
      const options: uiMaterial.ImmersiveOptions = {
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        colorInvert: true,
        applyShadow: true,
        interactive: true,
        lightEffect: light
      };
      return new uiMaterial.ImmersiveMaterial(options);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('uiMaterial.ImmersiveMaterial (glass+light) failed: ' + error.code.toString());
      return undefined;
    }
  }

  /** 语义 id -> MaterialType。 */
  static typeOf(id: string): hdsMaterial.MaterialType {
    if (id === MaterialKind.IMMERSIVE) {
      return hdsMaterial.MaterialType.IMMERSIVE;
    }
    if (id === MaterialKind.NONE) {
      return hdsMaterial.MaterialType.NONE;
    }
    return hdsMaterial.MaterialType.ADAPTIVE;
  }

  /** 语义 id -> MaterialLevel（四档）。 */
  static levelOf(id: string): hdsMaterial.MaterialLevel {
    if (id === MaterialGrade.EXQUISITE) {
      return hdsMaterial.MaterialLevel.EXQUISITE;
    }
    if (id === MaterialGrade.GENTLE) {
      return hdsMaterial.MaterialLevel.GENTLE;
    }
    if (id === MaterialGrade.SMOOTH) {
      return hdsMaterial.MaterialLevel.SMOOTH;
    }
    return hdsMaterial.MaterialLevel.ADAPTIVE;
  }

  /**
   * 菜单 / 弹窗类组件的沉浸式系统材质选项（组件级开启方式之一）。
   *
   * 菜单、弹窗、Select 气泡等通过 options 里的 systemMaterial 字段开启沉浸光感，且**全页面生效**
   * （不受标题栏 / 底部 TabBar 生效区域的限制）。设备 / SDK 不支持时返回不带 systemMaterial 的
   * 普通选项，菜单照常弹出、不会崩。
   *
   * 这里同样不加 materialColor（与玻璃一致：不加底色）；style 取 THICK —— 菜单要承载文字，
   * 厚模糊更易读，厚度与“是否有底色”是两件事。
   * 用法：`.bindMenu(menuElements, MaterialController.menuOptions())`。
   */
  static menuOptions(enabled: boolean): MenuOptions {
    const options: MenuOptions = { mask: false };
    if (!MaterialController.materialUsable()) {
      return options;
    }
    if (!enabled) {
      // 菜单在应用级 ENABLE 下是"默认开材质"的组件，关闭只能靠 Material.empty。
      options.systemMaterial = uiMaterial.Material.empty;
      return options;
    }
    try {
      const light: uiMaterial.LightEffectOptions = { color: undefined };
      const immersive: uiMaterial.ImmersiveOptions = {
        style: uiMaterial.ImmersiveStyle.THICK,
        colorInvert: true,
        interactive: true,
        lightEffect: light
      };
      options.systemMaterial = new uiMaterial.ImmersiveMaterial(immersive);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error('uiMaterial.ImmersiveMaterial (menu) failed: ' + error.code.toString());
    }
    return options;
  }

  /**
   * 组装下发到 HdsTabs / HdsNavigation 的材质参数（HDS 的四档体系）。
   *
   * 两处收敛：
   * 1. 总开关关掉、或应用级配置为 DISABLE 时，材质类型直接给 NONE（DISABLE 下组件级也开不了）；
   * 2. 等级按华为文档 §5.4 的风险提示收敛：低算力设备（SMOOTH）只接受自适应档，
   *    强行 EXQUISITE / GENTLE 会卡顿发热，所以非 ADAPTIVE 的选择会被强制回 ADAPTIVE。
   *
   * 注意 uiMaterial 没有 ADAPTIVE 档（只有 EXQUISITE / GENTLE / SMOOTH，且天然自适应、
   * 不能设置）；ADAPTIVE 是 hdsMaterial 独有档位，两套体系不要混用。
   */
  static params(typeId: string, levelId: string, immersiveOn: boolean): SystemMaterialParams {
    const on: boolean = immersiveOn && MaterialController.appMaterialOn();
    const level: hdsMaterial.MaterialLevel = MaterialController.levelOf(levelId);
    const adaptive: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;
    const result: SystemMaterialParams = {
      materialType: on ? MaterialController.typeOf(typeId) : hdsMaterial.MaterialType.NONE,
      materialLevel: MaterialController.lowCompute() ? adaptive : level
    };
    return result;
  }
}
