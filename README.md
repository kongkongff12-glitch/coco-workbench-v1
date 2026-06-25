# COCO 客户会议白板 v3

打开 `app.html` 即可使用；`index.html` 是默认会议白板入口，`workbench.html` 保留旧版资料看板。

- 数据来源：COCO Notion 导出 zip 中筛选后的业务表格。
- 已排除：团队成员资料、账号列表、聊天记录存档，以及用户另外提供的人事/人格/客户工作原则类文档。
- v3 定位：替代会议白板，展示老板先看、成员录入、微信群聊日报、飞书社媒看板、客户历史、会议白板、执行进展、交付证据、历史资料和多客户框架。
- 飞书社媒看板：https://my.feishu.cn/wiki/KGJJwc6iOiFMeokvIJrcQM81n1d?sheet=1Jbfs5
- 成员录入：当前先保存到个人浏览器 localStorage，并支持导出/导入 JSON 录入包。
- 下一版建议：接 GitHub 写回、飞书多维表或轻量数据库，让所有成员录入后实时共享。

## 部署

主线目录固定为 `D:\codex\coco-pages-fix-deploy`。部署脚本是：

```powershell
.\deploy-github-pages.ps1
```

第一次部署前先授权一次：

```powershell
.\setup-github-token.ps1
```

它会把 GitHub token 写到 `D:\codex\.secrets\github_token`。部署脚本会优先读取这个 token，否则使用 `D:\codex\.gh-config` 的 GitHub CLI 登录状态；GitHub Pages 发布源会设置为仓库根目录 `/`。
