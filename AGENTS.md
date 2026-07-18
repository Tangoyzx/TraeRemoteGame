# AGENTS.md

本文件是本项目对所有 AI coding agent(Trae / Cursor / Codex / Aider 等)的强制工作流约定。
开始任何修改前请先读完本文件。已存在的 `.codex/skills/git-version-workflow/SKILL.md` 是更详细的实现参考。

---

## 规则 1:直接在 `main` 分支上开发

- **不要** 创建 `trae/agent-*`、`feature/*` 等临时分支。
- 所有 commit 直接打到本地 `main`,然后推送到 `origin/main`。
- 仓库的工作流是 trunk-based,不要擅自引入分支策略。
- 远端历史遗留的 `trae/agent-*` 分支不要再新增;若发现误建的,合并后用 `git push origin --delete <branch>` 清理。

## 规则 2:每次推送到远端前必须 bump 版本号

### 源位置

版本号定义在 [scripts/main.gd](scripts/main.gd) 的 `const GAME_VERSION := "vX.Y.Z"`,
UI 顶部居中 `version_label` 会显示该字符串。
**这是用户验证"新版本部署成功"的唯一可见标识**。

### Bump 规则

- **格式**: `vMAJOR.MINOR.PATCH`,如 `v1.1.8`
- **何时 bump**: 任何将要推送到远端的 commit 之前(即使改动只是文档、平衡性调整、bugfix 都要 bump)
- **如何 bump**: 末位 `PATCH` +1,例如 `v1.1.7` → `v1.1.8`
- **bump MINOR / MAJOR**: 需要用户明确指示,不要擅自跳位
- **bump 顺序**: 先改版本号 → 再 stage → 再 commit,保证版本变更和功能变更在同一个 commit 里
- **绝不跳过**: 即使觉得"只是小改动",也必须 bump
- **绝不复用**: 同一个 `GAME_VERSION` 字符串不能出现在两个推送的 commit 中。
  如果上次忘了 bump,这次 commit 必须把版本号 bump 到正确值并在 commit message 里说明跳变

### 不要被其他规则覆盖

即使任务看起来与版本号无关(例如本规则的固化、文档更新、CI 配置改动),
只要这个 commit 会推送到远端,就必须先 bump `GAME_VERSION`。

---

## 参考实现

更详细的 PowerShell 脚本和工作流细节在 [.codex/skills/git-version-workflow/SKILL.md](.codex/skills/git-version-workflow/SKILL.md)。
但本 `AGENTS.md` 是规则来源(source of truth);若两者冲突,以本文件为准。
