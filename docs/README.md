# COCO 客户工作台 v1

打开 `index.html` 即可使用。

- Vercel 固定生产网址建议使用：`https://coco-workbench-v1-aiwatch.vercel.app`
- 不要把带随机码的网址当成固定地址，例如 `coco-workbench-v1-k6dpakctr-aiwatch.vercel.app`。这种是某一次部署的临时/快照地址，后面更新不会自动变成新版。
- 数据来源：COCO Notion 导出 zip 中筛选后的业务表格。
- 已排除：团队成员资料、账号列表、聊天记录存档，以及用户另外提供的人事/人格/客户工作原则类文档。
- 第一版录入：保存到浏览器 localStorage，用于演示流程。
- 本轮增强：新增 Actions 看板、文件库索引、SEO中心、会前自查、交付/事项/文件筛选、客户事项与 Action 本地更新。
- 本轮修复：首页增加空白页兜底提示；如果线上脚本报错，会直接显示错误，不再只剩空白背景。
- 下一版建议：接 GitHub API 写回 YAML，补 Basic Auth，并改成 GitHub 自动部署，让 Codex 更新代码后 Vercel 自动发布。
