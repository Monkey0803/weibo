# 鸿蒙微博客户端｜首版技术方案

状态：开发依据（接口清单为候选，待实测）
更新：2026-11-25

## 1. 基线与结构

从空目录创建 HarmonyOS 7 / API 26 的 ArkTS、Stage、ArkUI 应用，首版只交付手机 HAP。页面和状态采用 `@ComponentV2`、`@ObservedV2` 与 MVVM；网络、会话、解析和媒体能力放在共享层，页面只渲染状态并转发事件。首版不引入服务端，也不将微博 Cookie 上传至自建服务。

建议模块边界：

| 模块 | 职责 |
| --- | --- |
| `auth` | ArkWeb 登录页、会话检查、退出登录 |
| `data` | HTTP 请求、响应解析、错误分类、微博数据模型与仓库接口 |
| `features` | 首页、搜索、详情、评论、主页及各自 ViewModel |
| `media` | 图片加载和单实例视频播放控制 |
| `common/ui` | 列表卡片、加载/空/失败状态及主题资源 |

应用内公开接口以 `AuthRepository`、`FeedRepository`、`PostRepository`、`UserRepository` 和 `VideoController` 为界。核心模型为 `WeiboPost`（字符串 ID、作者、正文、时间、媒体、转发、互动数和本人点赞态）、`UserProfile`、`Comment`、`Page<T>`；微博 ID 全程用字符串保存，避免大整数精度损失。仓库返回明确的成功结果或 `AuthExpired`、`RateLimited`、`NetworkError`、`ParseError`、`PlatformRejected`，ViewModel 不直接解析原始 JSON。

## 2. 登录与会话

登录页只加载微博官方 HTTPS 登录域名，用户名、密码、验证码均在微博网页内输入。ArkWeb 的 `WebCookieManager.fetchCookieSync()` 可按完整 URL 获取 Cookie；应用在登录完成后调用微博会话探测接口验证，不以网页跳转本身判断成功。[鸿蒙 Cookie 接口参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-webview-webcookiemanager/)

请求前从 ArkWeb 会话读取目标域名适用的 Cookie，不把原始 Cookie 另存到 Preferences、日志、崩溃信息或仓库。写请求还需附上该会话对应的 CSRF 信息与网站要求的请求头；具体字段以联调结果为准。仅允许向 `weibo.com`、`m.weibo.cn` 及其已验证登录域名发送会话信息。遇到 401、403、网页跳转登录页或接口登录失效码时，统一转为 `AuthExpired`，停止写操作并展示重新登录入口。退出时清除本应用 ArkWeb 会话及内存状态。

扫码入口展示微博网页实际提供的二维码，需另一台设备扫描。若某种登录方式在当前微博网页中不可见或被风控拦截，应用说明原因，不模拟验证码或密码协议。

## 3. 网页接口适配

下表仅是代码参考中的**候选路径**，不是微博承诺的公开 API。开发第一步用本人账号逐项验证 URL、参数、响应和频率限制，再固定到适配层；页面不得拼接接口 URL。

| 能力 | 候选路径/来源 | 首版处理 |
| --- | --- | --- |
| 会话探测 | `m.weibo.cn/api/config`，[实现参考](https://github.com/wedaren/agentic-weibo-cli/blob/main/scripts/weibo_cli/api_client.py) | 验证是否登录及本人 UID |
| 关注时间线 | `m.weibo.cn/api/statuses/friends_timeline`，[实现参考](https://github.com/wedaren/agentic-weibo-cli/blob/main/scripts/weibo_cli/_svc_feed.py) | 按页读取，以微博 ID 去重 |
| 热门时间线 | `weibo.com/ajax/feed/hottimeline`，[实现参考](https://github.com/jackwener/weibo-cli/blob/main/weibo_cli/constants.py) | 未登录优先尝试；若实际需登录则显示登录引导 |
| 搜索 | `m.weibo.cn/api/container/getIndex`，[实现参考](https://github.com/wedaren/agentic-weibo-cli/blob/main/scripts/weibo_cli/_svc_feed.py) | 只解析微博卡片，保留分页信息 |
| 详情、评论、主页 | 移动或桌面网页接口，[只读实现参考](https://github.com/jackwener/weibo-cli/blob/main/weibo_cli/constants.py) | 实测选定单一来源并统一模型 |
| 发评论、点赞、取消点赞 | `m.weibo.cn/api/comments/create`、`api/attitudes/create`、`api/attitudes/destroy`，[实现参考](https://github.com/wedaren/agentic-weibo-cli/blob/main/scripts/weibo_cli/_svc_write.py) | 用户触发；服务端确认后更新状态 |

HTTP 层设请求超时，GET 允许有限重试，写请求不自动重试。分页切换或离开页面时取消过期请求，避免旧响应覆盖新页。解析层对缺失字段给出安全默认值，对关键字段缺失返回 `ParseError`；长文和转发对象按接口返回结构递归解析且限制深度。正文中的 HTML 只转换为安全文本和可识别链接，不执行脚本。图片和视频 URL 只接受 HTTPS。

首版只缓存当前会话的内存列表和图片；不做持久化离线内容。登录、退出或账号变化时清空相关内存数据。对高频滑动请求进行合并，遵守服务端返回的限流信号，不实现绕过风控的自动请求策略。

## 4. 页面与视频数据流

首页 ViewModel 分别保存关注和热门列表、当前页、加载状态和滚动位置；刷新从第一页重新拉取，加载更多按 ID 去重。详情页以字符串微博 ID 拉取完整数据，评论单独分页。评论发送成功后用服务端返回对象插入列表；响应不明时重新查询，避免盲目重发。点赞按钮在请求期间禁用，成功后同步本人点赞态和计数。

视频由数据层提取封面和可播放 HTTPS 地址。进入播放页后创建一个 AVPlayer 实例，订阅状态与错误事件；后台、返回或切换视频时暂停并释放。优先使用接口提供的 MP4/HLS 资源，资源需要会话头时按 [AVPlayer 媒体源能力](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-media-avplayer/)验证后传入；无可播放地址、格式不支持或鉴权失败时显示错误，并提供打开对应微博网页的入口。列表不自动播放。

## 5. 实施顺序与验证

1. 创建可构建的 API 26 手机工程及基础导航、主题和占位页面。
2. **先验证接入可行性**：真机完成网页登录 → 读取会话 → 探测本人信息 → 读取关注列表 → 用测试微博验证评论与点赞。记录每个请求的成功/失败和响应结构，敏感值脱敏。
3. 固定适配层、模型和错误类型，再完成首页、搜索、详情、主页、评论与点赞页面。
4. 接入图片和 AVPlayer 视频，完成深浅色、安全区、文字放大及失败状态。
5. 运行构建、本地测试和真机走查，形成逐项验收记录。只有真实接口通过的项目才标记完成。

测试至少覆盖解析缺失字段与转发内容、分页去重、搜索空结果、登录失效、网络断开、写请求失败与结果不明、点赞并发点击，以及视频资源释放。真机验收覆盖三种网页登录入口在微博网页中的实际可见性、关注与热门内容、搜索、评论、点赞和视频播放。当前本机有 DevEco Studio 与 API 26 SDK，但 `hdc` 尚未连接设备；真机结果必须在设备连接后记录。

## 6. 风险与完成判据

网页接口和 Cookie 登录可能随微博页面、风控或账号权限变化；两个参考仓库也不提供移动客户端的稳定接口保证。某能力实测失败时保留明确的错误界面和测试记录，不通过抓取用户密码或伪造成功状态来补齐。官方开放平台的[使用条件](https://open.weibo.com/cli/quickstart)另需开发者认证与服务开通，目前没有这些权限。

技术交付完成须满足：工程构建成功、核心仓库测试通过、真机上登录与关注列表可用、评论和点赞获得服务端确认、视频能在应用内播放并正确释放资源；所有未通过项逐项列出。个人使用版本不宣称已具备公开上架条件。
