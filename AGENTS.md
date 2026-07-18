# AGENTS.md

本文件是本项目对所有 AI coding agent（Trae / Cursor / Codex / Aider 等）的强制工作流约定。
开始任何修改前请先读完本文件,已存在的 `.codex/skills/git-version-workflow/SKILL.md` 是更详细的实现参考。

---

## 规则 1:直接在 `main` 分支上开发

- **不要** 创建 `trae/agent-*`、`feature/*` 等临时分支。
- 所有 commit 直接打到本地 `main`,然后推送到 `origin/main`(见规则 2)。
- 仓库的工作流就是 trunk-based,不要擅自引入分支策略。
- 已存在的 `trae/agent-*` 远端分支是历史遗留,不要再新增;若发现远端有自己之前误建的分支,合并后用 `git push origin --delete <branch>` 清理。

## 规则 2:推送远端的标准方式(重要,不要判断错)

### 沙箱内 `git push` 命令永远会失败

在 Trae 云端沙箱里直接执行 `git push origin main` 会报:

```
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

这是**环境限制,不是权限拒绝**。原因:沙箱里没有 GitHub HTTPS 凭据,也没有 credential helper,且非交互模式无法弹出登录框。**不要**把这个错误解释为"无权推送 main"或"必须走 PR 才能合并 main"。

### 正确做法:用 Trae IDE UI / 平台能力推送

沙箱外的 Trae 平台自带 GitHub OAuth 集成,具备推任意分支(包括 `main`)的能力。
所以推送远端的正确路径是:

1. 沙箱内完成 commit(可以正常 `git add` / `git commit`,这些不需要凭据)。
2. 在沙箱**外**通过 Trae IDE UI 的"推送"或"Commit & Push"按钮完成推送 —— 这一步用平台凭据,不经过沙箱。
3. 推送完成后,沙箱内 `git fetch origin` 可以拉到最新远端状态做后续验证。

### 如果用户要求"推送"而你只能调沙箱命令

- 不要回答"无法推送"或"需要 PR"。
- 明确告诉用户:**修改已 commit 到本地 main,需要在 Trae IDE UI 上点推送按钮**(或等价操作),并解释沙箱 `git push` 失败的原因是凭据缺失而非权限拒绝。
- 不要建议用户去手动创建 PR、改 SSH 等绕路方案。

### 已验证可行的方式

- ✅ Trae IDE UI 推送按钮(平台凭据,可推任意分支)
- ✅ 用户本地终端已配置好凭据后 `git push`
- ❌ 沙箱内 `git push`(永远失败,凭据缺失)
- ❌ 建议 PR 合并(本项目是 trunk-based,不走 PR 流程)

## 规则 3:每次推送到远端前必须 bump 版本号

### 源位置

版本号定义在 [scripts/main.gd](scripts/main.gd) 的 `const GAME_VERSION := "vX.Y.Z"`,UI 顶部居中 `version_label` 会显示该字符串。
**这是用户验证"新版本部署成功"的唯一可见标识**。

### Bump 规则

- **格式**: `vMAJOR.MINOR.PATCH`,如 `v1.1.8`
- **何时 bump**: 任何将要推送到远端的 commit 之前(即使改动只是文档、平衡性调整、bugfix 都要 bump)
- **如何 bump**: 末位 `PATCH` +1,例如 `v1.1.7` → `v1.1.8`
- **bump MINOR / MAJOR**: 需要用户明确指示,不要擅自跳位
- **bump 顺序**: 先改版本号 → 再 stage → 再 commit,保证版本变更和功能变更在同一个 commit 里
- **绝不跳过**: 即使觉得"只是小改动",也必须 bump
- **绝不复用**: 同一个 `GAME_VERSION` 字符串不能出现在两个推送的 commit 中。如果上次忘了 bump,这次 commit 必须把版本号 bump 到正确值并在 commit message 里说明跳变

### 不要被其他规则覆盖

即使任务看起来与版本号无关(例如本规则的固化、文档更新、CI 配置改动),只要这个 commit 会推送到远端,就必须先 bump `GAME_VERSION`。

---

## 参考实现

更详细的 PowerShell 脚本和工作流细节在 [.codex/skills/git-version-workflow/SKILL.md](.codex/skills/git-version-workflow/SKILL.md)。
但本 `AGENTS.md` 是规则来源(source of truth);若两者冲突,以本文件为准。
