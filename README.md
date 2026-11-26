# HarmonyOS 微博客户端

一个使用 ArkTS、ArkUI 和 HarmonyOS Design System 构建的第三方微博客户端实验项目。

## 当前能力

- 内置微博移动网页登录，并同步 ArkWeb Cookie 到原生网络请求
- 热门微博、关键词搜索、个人主页与用户微博
- 微博详情、图片、视频和评论浏览
- 深浅色主题、响应式布局及 HarmonyOS 沉浸光感适配
- 脱敏网络诊断日志和分类错误处理

微博移动网页接口并非稳定的开放 API，关注信息流、详情补充和写操作可能因服务端策略变化而不可用。

## 开发环境

- DevEco Studio
- HarmonyOS SDK 26
- 最低兼容 API 23

克隆项目后，请在 DevEco Studio 中配置自己的调试签名。工程不会提交证书、密钥或签名密码。

## 构建

```bash
hvigorw --mode module -p module=entry@default -p product=default assembleHap
```

产品与技术设计说明见 [docs/PRD.md](docs/PRD.md) 和 [docs/TECH_DESIGN.md](docs/TECH_DESIGN.md)。
