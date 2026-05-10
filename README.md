# qulv-agent-obsidian-install

GitHub 仓库名：`qulv-agent-obsidian-install`。

这套部署包用于把客户电脑初始化成可交付的 Agent 工作环境：

- Agent：Claude Code，通过 CodePilot 客户端管理
- 知识库：Obsidian vault，默认作为所有“知识库”请求的落点
- 自动化：Claude Code skills、Obsidian CLI、Lark CLI
- 系统：macOS、Windows、Linux

---

## 关于作者

这个开源工具来自我们的企业 AI 服务实践——

我们核心提供**企业 AI 服务**，具体业务包括：

1. **企业 AI 培训**
2. **企业 AI 转型咨询**
3. **落地工具搭建、AI 工具定制及 Skill 定制**
4. **企业 AI 转型全程陪跑**

感兴趣可扫码添加微信 👇

![扫码添加微信](./assets/poster.png)

---

## 快速使用

### 方式一：远程一行命令（推荐）

类似 Homebrew / Rust / Bun 的体验，不需要手动判断系统、不需要解压、不需要找路径，**复制粘贴一行命令到终端即可**：

#### macOS / Linux（终端 / Terminal）

```bash
curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh | bash
```

#### Windows（PowerShell，建议右键"以管理员身份运行"）

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.ps1 | iex
```

入口脚本会自动按以下顺序定位完整安装包：

1. **优先**：`~/Downloads/自动部署脚本/`（已解压目录）
2. **其次**：`~/Downloads/自动部署脚本.zip` / `Agent-Obsidian-install.zip`（自动解压）
3. **兜底**：从 GitHub `git clone`（不含离线包，回退在线下载依赖）

为达到最佳体验，建议先把完整 zip（含 `离线安装包/`）下载到 `~/Downloads/`，再跑上面的一行命令。

### 方式二：本地双击入口（已下载完整包）

适合已经把完整 `自动部署脚本/` 目录或 zip 解压到本地的情况：

| 系统 | 入口文件 |
|------|----------|
| macOS | 双击 `Mac系统/install-mac.command` |
| Windows | 右键 `Win系统/install-windows.bat` → 以管理员身份运行 |
| Linux | 终端运行 `bash scripts/bootstrap.sh` |

### 方式三：手动调用主脚本（高级）

```bash
# macOS / Linux
bash scripts/bootstrap.sh --cn         # 启用国内 npm 镜像
bash scripts/bootstrap.sh              # 不启用镜像
bash scripts/bootstrap.sh --dry-run    # 干跑模式，不实际写文件

# Windows PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
.\scripts\bootstrap.ps1 -ChinaMirror   # 启用国内 npm 镜像
.\scripts\bootstrap.ps1 -DryRun        # 干跑模式
```

## 推荐机制

不要做成“一个巨大脚本硬干到底”。更稳的结构是：

| 层 | 文件 | 作用 |
|---|---|---|
| 入口层 | `scripts/bootstrap.sh` / `scripts/bootstrap.ps1` | 识别系统并分发 |
| 系统层 | `scripts/install-macos.sh` / `scripts/install-linux.sh` / `scripts/bootstrap.ps1` | 安装依赖、客户端、CLI、目录和规则 |
| 配置层 | `templates/CLAUDE.md` | 写入 Claude Code 长期规则 |
| 能力层 | `payload/skills/` | 放脱敏后的通用 skills |
| 离线层 | `自动部署脚本/离线安装包/` | 放 Git、Node、Claude Code、Lark CLI 等离线包 |
| 人工层 | `templates/MANUAL_STEPS.md` | 列出必须人类确认的步骤 |
| 清单层 | `manifest.json` | 记录版本、包名、默认 skills、缺口 |

这样做的好处是：脚本可以反复运行，客户电脑中途失败也能继续；必须手动点的地方不会卡死；以后新增 Skill 或换版本，只改 manifest 和 payload。

## 脚本会自动做什么

- 识别系统：macOS / Linux / Windows
- macOS 识别芯片：`arm64` 走 M 芯片包，`x86_64` 走 Intel 包
- 自动搜索安装包目录：
  - 脚本同级 `自动部署脚本`
  - 脚本同级 `packages/自动部署脚本`
  - 当前用户 `Downloads/自动部署脚本`
  - Windows `C:\自动部署脚本`、`C:\Downloads\自动部署脚本`
- 安装基础环境：
  - macOS：优先离线 Git/Node pkg，缺失时回退 Homebrew
  - Windows：优先离线 Git exe / Node msi，缺失时回退 winget
  - Linux：优先离线 deb，缺失时回退 apt/dnf/pacman
- 安装 Claude Code：`@anthropic-ai/claude-code`
- 安装 Lark CLI：`@larksuite/cli`
- 安装本地安装包：
  - CodePilot
  - Obsidian
- 创建工作目录：
  - macOS：`~/Desktop/CodePilot/Bridge`
  - Windows：优先 `D:\CodePilot\Bridge`，没有 D 盘则用桌面
  - Linux：`~/CodePilot/Bridge`
- 创建 Obsidian vault 目录：
  - macOS：`~/Desktop/CodePilot/Obsidian/ClaudeCode`
  - Windows：优先 `D:\CodePilot\Obsidian\ClaudeCode`
  - Linux：`~/CodePilot/Obsidian/ClaudeCode`
- 写入 `CLAUDE.md`：
  - 工作区 `CLAUDE.md`
  - 全局 `~/.claude/CLAUDE.md`
- 安装脱敏后的基础 skills 到 `~/.claude/skills`
- 设置 24 小时待机：
  - macOS：默认设置交流电源下不睡眠
  - Windows：默认设置 AC/DC 下不睡眠、不休眠
  - Linux：提供可选 systemd sleep mask
- 安装失败时输出日志路径，让客户把失败日志回传给交付人员
- 在终端展示水印，但不会写入 `CLAUDE.md`

## 离线安装包目录

推荐把所有不能稳定在线下载的东西放在：

```text
自动部署脚本/
├── Mac系统/
├── Win系统/
├── Linux系统/
└── 离线安装包/
```

脚本会优先扫描 `离线安装包/`，找不到再走在线安装。

推荐结构：

```text
离线安装包/
├── mac-arm64/
│   ├── node-v*-darwin-arm64.pkg
│   └── git-*.pkg
├── mac-x64/
│   ├── node-v*-darwin-x64.pkg
│   └── git-*.pkg
├── win-x64/
│   ├── Git-*.exe
│   └── node-v*-x64.msi
├── linux-amd64/
│   ├── git/*.deb
│   └── node/*.deb
├── linux-arm64/
│   ├── git/*.deb
│   └── node/*.deb
└── npm/
    ├── anthropic-ai-claude-code-*.tgz
    └── larksuite-cli-*.tgz
```

实际搜索是递归的，所以不强制文件一定在这些精确子目录里；但按这个结构放，后续维护最省心。更详细说明见 [templates/OFFLINE_PACKAGES.md](templates/OFFLINE_PACKAGES.md)。

## 必须人工完成的步骤

这些步骤脚本可以提醒，但不应该偷偷代替人做：

1. CodePilot API Key 配置：左下角 `[设置]` -> `[服务商]` -> 选择类型 -> 手动填写 API Key
2. macOS 未签名 App 的“仍要打开”
3. Windows SmartScreen 或管理员确认
4. Obsidian CLI 开关注册
5. Lark CLI 登录授权：脚本只安装，不预填、不代授权
6. 验证 Agent 能实际读写 Obsidian vault

详细清单在 [templates/MANUAL_STEPS.md](templates/MANUAL_STEPS.md)。

## 国内网络处理

`--cn` / `-ChinaMirror` 会把 npm 安装切换到：

```text
https://registry.npmmirror.com
```

这个对 Claude Code 和 Lark CLI 有用。本次检查时：

- `@anthropic-ai/claude-code` 在 npmjs 与 npmmirror 上版本一致
- `@larksuite/cli` 在 npmmirror 可访问

但 Homebrew、winget、apt 仍可能受网络影响。客户交付时建议优先把 Git、Node、Claude Code、Lark CLI 的离线包放进 `自动部署脚本/离线安装包/`。

## 当前安装包缺口

本机 `~/Downloads/自动部署脚本` 里已经有：

- macOS CodePilot arm64/x64
- macOS Obsidian dmg
- Windows CodePilot exe
- Windows Obsidian exe
- Linux CodePilot amd64/arm64 deb
- Linux Obsidian amd64 deb

缺：

- Linux Obsidian arm64 deb
- Git 离线安装包
- Node LTS 离线安装包

## 默认 Skill 包建议

第一版建议只放“通用基础能力”：

- `obsidian-vault-manager`
- `obsidian-cli`
- `obsidian-markdown`
- `search-first`
- `multi-search-engine`
- `lark-shared`
- `lark-doc`
- `lark-drive`
- `lark-im`
- `lark-sheets`
- `lark-task`
- `lark-calendar`
- `markitdown`
- `pdf`
- `docx`
- `xlsx`
- `article-writing`
- `markdown-mermaid-writing`
- `humanizer-zh`

不建议默认塞进客户包：

- 内部文风、客户资料、定价系统、法律顾问、深研 API、社媒账号相关 skills

这些应该做成可选模块，由交付人员按客户项目单独启用。

## 验收标准

安装结束后至少验证：

```bash
node --version
npm --version
claude --version
lark-cli --version
```

Obsidian 打开并启用 CLI 后，再验证：

```bash
obsidian help
```

最后在 CodePilot 中打开工作目录，确认 Claude Code 启动后能读到 `CLAUDE.md`，并能按要求把内容保存到 Obsidian vault。