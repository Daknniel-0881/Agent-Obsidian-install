---
name: handoff
description: Use when an Agent task needs to be handed off to another Agent / new session, or when context window is approaching limit and conversation needs to be compacted into a transferable artifact. Triggers include "Agent 交接"、"上下文管理"、"Agent 协作"、"压缩对话"、"换会话继续"、"handoff"、"接手"、"新 session 接力". Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

# Handoff Skill

把当前会话压缩成一份 handoff 文档，让新的 Agent / 新 session 可以无缝接手继续工作。

## 何时使用

- **Agent 交接**：父 Agent 把任务派给子 Agent，需要传递完整上下文
- **会话压缩前**：上下文窗口接近上限，主动压缩成可继承的 artifact
- **跨 session 接力**：今天没干完的活，明天换个新 session 继续
- **多 Agent 协作**：多团队架构里，PM ↔ 执行 Agent 之间的 ExecSpec 之外的补充上下文
- **换模型协作**：从 Claude 切到 Codex / Gemini，需要中转协议

## 执行规则

写一份 handoff 文档，总结当前对话状态，让新 Agent 能从这份文档无缝继续工作。

1. **保存路径**：用 `mktemp -t handoff-XXXXXX.md` 生成临时路径（先 Read 一次该路径，再 Write）
2. **不要重复**：已经在 PRDs / plans / ADRs / issues / commits / diffs 里写过的内容，**只引用路径或 URL**，不重复粘贴
3. **建议下游 skill**：如果下一个 session 应该走某个 skill（<your-writing-style> / agent-design 等），明确写出来
4. **如果用户传了 argument**：把 argument 当成"下一个 session 要做什么"的描述，handoff 文档围绕这个目标裁剪

## handoff 文档结构（建议模板）

```markdown
# Handoff: <一句话主题>
**生成时间**：YYYY-MM-DD HH:MM
**当前 Agent**：<Claude Code / Codex>
**目标会话**：<argument 的内容>

## 1. 任务上下文
<这个任务是什么，为什么做，用户的原始诉求>

## 2. 已经完成
- [x] xxx（路径：xxx）
- [x] xxx（PR：xxx）

## 3. 进行中
- [ ] xxx（卡在哪里 / 下一步是什么）

## 4. 还没做
- [ ] xxx
- [ ] xxx

## 5. 关键决策（不重复，只列）
- 决策 X：见 `path/to/ADR-001.md`
- 决策 Y：见 commit `abc1234`

## 6. 关键文件 / 链接
- xxx：路径 / URL
- xxx：路径 / URL

## 7. 下一个 Agent 应该用的 skill
- `<your-writing-style>`（写作）
- `<your-publish-skill>`（内容发布）

## 8. 注意事项 / 红线
<用户的禁忌、风格偏好、必须避开的坑>

## 9. 新会话开场建议
<给新 Agent 的第一句话建议，比如"先 Read xxx，然后继续 step 4"</cope>
```

## 与多团队架构的协同

- **ExecSpec 7 段** 是父→子单向派单协议（mission/context/constraints/deliverables/tools/escalation/trace_id），首发派单走 ExecSpec
- **handoff 文档** 是双向状态交接，用在：
  - 子 Agent 干到一半要换人 → 写 handoff，新子 Agent 接手
  - 同一个 Agent 跨 session → 写 handoff 作为 session 间桥梁
  - PM 之间协作 → handoff 比 ExecSpec 更轻，记录"现状+卡点+下一步"

## 出处

- 来源：mattpocock/skills（GitHub）
- 推荐人：@vikingmute、@mattpocockuk（X）
- 入库时间：2026-05-09
- 知识库登记：`06-Library/工具清单/handoff-Agent交接Skill.md`
