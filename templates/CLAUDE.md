# Agent 工作规则

> 本文件是 Claude Code 在本机的长期工作守则。每次对话启动会自动加载。

## 工作目录

CodePilot / Claude Code 默认工作目录：

```text
__BRIDGE_PATH__
```

## 知识库默认规则

以后用户提到"知识库"、"保存到知识库"、"入库"、"沉淀到知识库"、"存到 Obsidian"时，默认指的是本机 Obsidian vault：

```text
__VAULT_PATH__
```

除非用户明确指定其他位置，否则所有需要长期保存的内容都应保存到这个 Obsidian vault 的合适目录下。

## 保存原则（PARA + 8 层路由）

1. 先判断内容类型，再选择目录。分类不确定时，先保存到 `00-Inbox/`。
2. 项目交付物 → `01-Projects/`（有明确交付物、有结束时间的项目）
3. 长期领域内容 → `02-Areas/`（持续运营的领域、技能、爱好）
4. 客户、合作方、人物相关 → `03-People/`（同行案例、客户档案、合作伙伴、思想导师）
5. 可复用概念 → `04-Concepts/`（跨域核心概念、双向链接枢纽）
6. SOP、方法论、流程 → `05-Playbooks/`
7. 工具、资料、书籍、论文、失败案例 → `06-Library/`
8. 已结案项目、转录、大体量原料 → `07-Archive/`

## 原文神圣原则

用户给的原文（朋友圈、口述、笔记、草稿、外部文章、访谈转录、客户原始材料）**一字不改**：

- 不改标点（"，"不能换成"、"，"……"不能改成"…"）
- 不改用词、不增句不减句不合并段
- 不"润色"、不"通顺化"、不"补充逻辑"
- 加小标题/分节是允许的，但小节内的原句必须原样照搬
- 如有歧义/疑似错别字，先问用户，不擅自改

需要分析或归纳时，把原文和分析分开放：原文段落原样保留，下方追加 `> 分析：...` 引用块。

## Wiki Link 和索引

创建或更新笔记后，优先补充相关 Wiki Link，并在合适的 MOC（Map of Content）或索引笔记中登记。不要只把文件丢进目录就结束。

## 先检索后回答

用户提问时（尤其是涉及历史决策、过往项目、人物档案、领域知识的问题），**先在 vault 里检索**，再回答。三步法：

1. 目录路由：根据问题主题猜测可能的 PARA 目录
2. 关键词 Grep：用 obsidian-cli 或 grep 在 vault 全局检索
3. 双向链接跳转：从 hit 的笔记沿 Wiki Link 扩散

无论检索结果是否相关，回答里要标注「已检索 / 未检索」。例外：纯代码操作、文件读写、一句话确认（≤20 字）。

## 可用 Skill 一览

本机 `~/.claude/skills/` 已预装 28 个 skill，按场景调用：

| 场景 | 推荐 Skill |
|------|------------|
| 知识库管理 | `obsidian-vault-manager`（路由+索引+CLI 优先级） |
| Obsidian 增删改查 | `obsidian-cli` |
| Markdown 写作 | `obsidian-markdown`、`markdown-mermaid-writing` |
| 找其他 skill | `find-skills` |
| 网络搜索 | `search-first`、`multi-search-engine` |
| 飞书云文档 | `lark-doc`、`lark-drive`、`lark-shared` |
| 飞书消息/会话 | `lark-im`、`lark-mail` |
| 飞书表格/任务/日历 | `lark-sheets`、`lark-task`、`lark-calendar`、`lark-base` |
| 长文写作 | `article-writing`、`humanizer-zh` |
| 小红书图文 | `xhs-image-creator` |
| 文档转换 | `markitdown`（任何格式 → Markdown） |
| PDF / Word / Excel / PPT 处理 | `pdf`、`docx`、`xlsx`、`pptx` |
| AI 调研 | `deep-research`（Gemini 深度研究） |
| AI 生图 | `generate-image`（OpenRouter 多模型） |
| Agent 交接 | `handoff` |
| 跨会话续接 | `session-continuity` |

不确定用哪个 → 先 `find-skills` 检索。

## Obsidian CLI 优先级

如果 Obsidian 已开启命令行界面（左下角齿轮 → 关于 → 高级 → 命令行界面 → 注册），优先使用 `obsidian` 命令完成读取、创建、搜索和追加：

```bash
obsidian list             # 列出 vault 内容
obsidian read <path>      # 读取笔记
obsidian create <path>    # 创建笔记
obsidian search <query>   # 全文搜索
obsidian append <path>    # 追加内容
```

如果 CLI 未启用，则直接在 vault 文件夹中创建 / 编辑 Markdown 文件，并提醒用户去 Obsidian 设置里完成 Obsidian CLI 注册。

## 安全边界

- 不要把 API Key、账号密码、Token、客户敏感原文保存到公开模板或通用 Skill 中
- 涉及客户隐私时，保存前先确认范围和目录
- 推送到 GitHub 公开仓库前必须脱敏：路径、姓名、邮箱、Token、客户信息全部替换或删除
- 飞书云文档分享前确认权限范围（部门 / 公开 / 指定人员）

## 任务交付

- 任务完成后提供所有涉及文件的完整路径
- 复杂任务（>3 步）建议先列计划再动手
- 文件改动前先 Read 再 Edit；新文件用 Write，已有文件不用 Write 覆盖
- Bash 命令执行前先确认目标，破坏性操作（rm / git reset / push --force）必须先得到用户确认
