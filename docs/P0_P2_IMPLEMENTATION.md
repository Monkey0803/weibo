# 微博网页接口 P0–P2 实施记录

更新：2026-11-26

## 开源实现核对

本轮以仍有维护痕迹、且明确列出当前网页接口能力的项目交叉核对，不把这些路径视为微博承诺的公开 API：

- [OpenWeb 微博适配进度](https://github.com/imoonkey/openweb/blob/main/src/sites/weibo/PROGRESS.md)：覆盖热搜、用户关系、收藏、关注等读写能力。
- [OpenWeb 微博接口说明](https://github.com/imoonkey/openweb/blob/main/src/sites/weibo/DOC.md)：用于核对桌面 Ajax 接口的参数形式。
- [weibo-cli](https://github.com/jackwener/weibo-cli)：用于核对热搜、转发列表、关注与粉丝列表能力。
- [MediaCrawler](https://github.com/NanmiCoder/MediaCrawler)：用于核对移动搜索容器及分类值。
- [agentic-weibo-cli](https://github.com/wedaren/agentic-weibo-cli)：用于核对移动端发布、评论、转发和删除写接口。

## 已实现范围

| 优先级 | 能力 | 应用入口 |
| --- | --- | --- |
| P0 | 热搜、关注列表、粉丝列表、转发列表 | 首页标题栏热搜；主页关注/粉丝数；微博转发菜单 |
| P1 | 评论楼中楼、关注/取消关注、收藏/取消收藏、综合/实时/热门/视频搜索 | 评论区、他人主页、微博菜单、搜索页分类栏 |
| P2 | 扩展个人资料、发布纯文字微博、删除本人微博 | 主页资料卡、首页标题栏发布、本人微博菜单 |

同时补齐首页游标传递、服务端新评论对象直接插入、发布后刷新首页，以及写操作中的登录态、并发禁用和删除确认。

## 接口适配与边界

接口集中在 `WeiboRepository`，页面不拼接 URL。移动端和桌面端共用 ArkWeb 登录态；桌面写接口携带 CSRF，请求日志不记录 Cookie、正文和查询参数。解析器兼容直接对象、嵌套对象和数组列表三类常见响应外形。

这些是非公开网页接口，可能受账号、风控、A/B 响应和接口改版影响。所有功能都有加载、空或失败状态，但真实写操作仍须在本人测试账号上逐项验收；未连接设备时不能把编译成功等同于线上接口通过。

## 验证

- 主 HAP：`assembleHap` 通过。
- ohosTest HAP：`assembleHap` 通过，新增热搜、用户列表、楼中楼、发布返回和收藏态解析用例。
- 当前 `hdc` 未发现可用目标，因此本轮未执行设备端 Hypium 和真实账号写操作。
