# AGENTS.md

本文件是本项目对所有 AI coding agent(Trae / Cursor / Codex / Aider 等)的强制工作流约定。
开始任何修改前请先读完本文件。已存在的 `.codex/skills/git-version-workflow/SKILL.md` 是更详细的实现参考。

---

## 规则 1:直接在 `main` 分支上开发

- **不要** 创建 `trae/agent-*`、`feature/*` 等临时分支。
- 所有 commit 直接打到本地 `main`,然后推送到 `origin/main`(见规则 2)。
- 仓库的工作流是 trunk-based,不要擅自引入分支策略。
- 远端历史遗留的 `trae/agent-*` 分支不要再新增;若发现误建的,合并后用 `git push origin --delete <branch>` 清理。

## 规则 2:推送远端的方式(实测真相,不要判断错)

### 沙箱内 `git push` 命令必然失败

在 Trae 云端沙箱里直接执行 `git push origin main` 会报:

```
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

**这是环境限制,不是权限拒绝**。沙箱内已验证:
- 无 `~/.git-credentials`
- 无 `~/.config/gh/`(`gh` CLI 未登录)
- 无 `~/.netrc`
- 无 credential helper

### 不要犯的误判(基于实测教训)

历史上 AI 在这个问题上犯过两次相反的错误,都要避免:

- ❌ **错误 A**:"沙箱 push 失败 = 推不了 main,必须走 PR 流程合并"
  → 不对。trunk-based 项目不走 PR,且远端 reflog 实测有过 `update by push` 记录。
- ❌ **错误 B**:"Trae 平台会自动同步 main commit 到远端,不需要任何操作"
  → 不对。实测 commit 后等 60 秒仍未同步到远端,自动同步不 100% 触发。

### 正确做法

当用户说"推送"或"提交到远端"时:

1. 沙箱内完成 `git add` + `git commit`(这些不需要凭据,可以正常执行)。
2. 告诉用户:commit 已完成,但**沙箱是临时的,本地拉不到这些 commit**,
   需要用以下方式之一把改动送到远端 main:

   - **方式 1(推荐)**:用户在 GitHub 网页直接编辑
     - 适合改动很小、文件少的情况(如纯 AGENTS.md 修改、版本号 bump)
     - 在 GitHub 网页打开对应文件,点编辑,粘贴沙箱里的最新内容,直接 commit 到 main
     - 不需要本地环境,最简单
   - **方式 2**:用户提供 GitHub Personal Access Token(有 `repo` 权限)
     - agent 在沙箱里用 token 配置 git credential helper 后执行 `git push origin main`
     - 推送完成后用户撤销 token
     - 适合改动较大、文件多的情况
   - **方式 3**:用户在本地终端 clone 后手动同步
     - 用户本地:`git clone https://github.com/<owner>/<repo>`
     - 把沙箱里的修改内容手动复制到本地(因为沙箱拉不到)
     - 本地 `git add` + `git commit` + `git push origin main`
     - 适合改动不大但用户想要本地审查的情况

3. 不要犯错误 A 或错误 B。最诚实的表述是:
   "沙箱里 git push 失败(无凭据),且沙箱临时用户拉不到。建议在 GitHub 网页直接编辑小改动,或提供 PAT 让沙箱帮你推。"

### 已验证的事实

- ❌ 沙箱内 `git push` 命令(永远失败,无凭据)
- ❌ Trae 平台自动同步(实测不可靠,有时会推有时不会)
- ✅ 用户在 GitHub 网页直接编辑 commit(最简单,适合小改动)
- ✅ 用户提供 PAT,agent 在沙箱配置凭据后推送(适合大改动)
- ❌ 不要默认用户有 Trae IDE 客户端

## 规则 3:每次推送到远端前必须 bump 版本号

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
