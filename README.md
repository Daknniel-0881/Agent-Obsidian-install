# qulv-agent-obsidian-install

「曲率 AI · Agent + Obsidian + 自动化环境」客户一键安装包。

## 关于曲率企业 AI 服务

本仓库是曲率企业 AI 落地工具链的一部分。曲率当前核心业务围绕 **FDE 前沿部署工程师** 展开：培养能把前沿 AI 能力部署到真实业务现场的人，并在此基础上为企业提供 AI 内训、AI 工具定制、轻量咨询与少量转型陪跑。

我们主要做：

- **FDE 前沿部署工程师人才培训**
- **企业 AI 内部培训**
- **企业 AI 工具定制**：Agent、知识库、自动化工作流、业务工具原型
- **企业 AI 转型陪跑与咨询**：以少量深度项目为主，服务真实业务落地

感兴趣可扫码添加微信：

![曲率企业 AI 服务海报](assets/qulv/qulv-ai-business-poster-readme.png)

当前 release 已发布：

- macOS：把安装包放到 `~/Downloads/Mac系统`，自动打开终端执行安装。
- Windows：把安装包放到 `Downloads\Windows系统`，自动解压并运行 `启动.bat`。

Linux 版本暂未发布到本仓库，后续测试稳定后再加入。

## 一条命令安装

macOS 用户打开系统自带「终端」，复制下面一整行并回车：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh)"
```

Windows 用户打开 PowerShell，复制下面一整行并回车：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.ps1 | iex"
```

这两个入口都会识别当前系统并下载对应 release 资产。macOS 入口会下载完整的 `Agent-Obsidian-install-Mac-final-20260521.20.zip`，Windows 入口会下载 `Agent-Obsidian-install-Windows-final-20260521.18.zip`。

## 国内网络备用命令

如果 `raw.githubusercontent.com` 在国内网络下访问很慢，可以先用下面的镜像备用入口。镜像只用于拉取入口脚本和安装包，安装包下载后会做 SHA256 校验，校验失败会停止安装。

macOS：

```bash
/bin/bash -c "$(curl -fsSL https://gh.llkk.cc/https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh)"
```

Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://gh.llkk.cc/https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.ps1 | iex"
```

脚本内部下载大文件时会按这个顺序尝试：

1. GitHub 官方 release 地址
2. `QULV_GITHUB_MIRROR_PREFIX` 指定的自定义镜像
3. `QULV_GITHUB_MIRRORS` 指定的多个自定义镜像
4. 内置备用镜像：`gh.llkk.cc`、`gh-proxy.com`、`mirror.ghproxy.com`

如果你有自己的稳定镜像，可以这样临时指定：

```bash
QULV_GITHUB_MIRROR_PREFIX="https://你的镜像域名/" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh)"
```

## 手动下载

如果一条命令不可用，可以打开本仓库右侧 Releases，下载最新版本里的资源包：

- `Agent-Obsidian-install-Mac-final-20260521.20.zip`
- `Agent-Obsidian-install-Windows-final-20260521.18.zip`
- `CHECKSUMS.txt`

macOS 手动方式：

1. 解压 `Agent-Obsidian-install-Mac-final-20260521.20.zip`
2. 把解压出来的 `Mac系统` 文件夹放到 `~/Downloads/Mac系统`
3. 打开 `Mac系统/复制到终端运行.txt`
4. Command + A 全选，Command + C 复制
5. 打开「终端」，Command + V 粘贴，回车运行

Windows 手动方式：

1. 解压 `Agent-Obsidian-install-Windows-final-20260521.18.zip`
2. 双击 `启动.bat`
3. 保持窗口打开，按提示完成安装

## 安装清单

以下为当前 release `v2026.05.21.20` 的实测清单。脚本会先检测，已安装则跳过，未安装才继续安装。账号授权类工具只安装命令和 Skill，不会代替客户登录。

### 系统组件、CLI 与桌面应用

| 项目 | macOS | Windows | 说明 |
|---|---:|---:|---|
| Apple Command Line Tools | 有 | 不适用 | macOS 开发基础工具 |
| Homebrew | 有 | 不适用 | macOS 包管理器，会按网络情况选择下载源 |
| Git | 有 | 有 | 代码与仓库基础工具 |
| Node.js / npm | 有 | 有 | Claude Code、Lark CLI、HyperFrames 等依赖 |
| Python 3.13 | 有 | 有 | 文档转换、下载器与 Python 工具依赖 |
| Claude Code CLI | 有 | 有 | `claude` 命令 |
| Lark CLI | 有 | 有 | `lark-cli` 命令，需客户自行授权 |
| HyperFrames CLI | 无 | 有 | Windows 包安装 `hyperframes` 命令 |
| 企业微信 CLI | 无 | 有 | Windows 包安装 `wecom-cli` 命令，需客户自行授权 |
| MarkItDown | 无 | 有 | Windows 包安装 `markitdown[all]` |
| yt-dlp | 无 | 有 | Windows 包安装视频/音频下载工具 |
| reportlab | 无 | 有 | Windows 包安装，作为 `any2pdf` 的 PDF 生成依赖 |
| FFmpeg | 无 | 有 | Windows 包内置 `ffmpeg-release-essentials.zip` 并安装 |
| CodePilot | 有 | 有 | macOS 内置 DMG，Windows 内置 EXE |
| Obsidian | 有 | 有 | macOS 内置 DMG，Windows 内置 EXE |
| Obsidian CLI | 有 | 提示注册 | macOS 尝试注册命令；Windows 需在 Obsidian 内注册 |
| 全局 `CLAUDE.md` | 有 | 有 | 写入默认知识库路径与使用规则 |
| CodePilot 工作目录 | 有 | 有 | 创建 `CodePilot/Bridge` 与 `CodePilot/Obsidian` |

### 随包应用与离线资源

macOS 随包文件：

- `apps/CodePilot-0.54.0-arm64.dmg`
- `apps/CodePilot-0.54.0-x64.dmg`
- `apps/Obsidian-1.12.7.dmg`

Windows 随包文件：

- `apps/CodePilot.Setup.0.54.0.exe`
- `apps/Obsidian-1.12.7.exe`
- `apps/ffmpeg-release-essentials.zip`

### 随包 Skills

macOS / Windows 当前随包 Skills 已同步为同一批 38 个，清单先按 Windows 测试稳定版本作为标准：

| 类别 | Skills |
|---|---|
| Agent / 安全 / 桥接 | `agent-reach`, `cc-shield`, `codexbridge`, `find-skills`, `skill-creator`, `mcp-builder`, `search-first`, `multi-search-engine`, `lengyi-recommended-skills` |
| Obsidian 知识库 | `obsidian-vault-manager`, `obsidian-cli`, `obsidian-markdown` |
| 飞书 / Lark | `lark-shared`, `lark-im`, `lark-doc`, `lark-drive`, `lark-sheets`, `lark-calendar`, `lark-task` |
| 文档与格式转换 | `docx`, `pdf`, `pptx`, `xlsx`, `markitdown`, `lovstudio-any2pdf`, `markdown-mermaid-writing` |
| 内容、设计与前端 | `article-writing`, `board`, `frontend-design`, `ui-ux-pro-max`, `guizang-ppt-skill`, `humanizer-zh` |
| 视频与 HyperFrames | `hyperframes`, `hyperframes-cli`, `hyperframes-media`, `hyperframes-registry`, `remotion-best-practices` |
| RSS / 微信公众号说明 | `weress` |

### 随包工具源码目录

当前 release 中，`payload/tools` 不是主要交付方式：

- macOS 包：没有独立 `payload/tools` 工具源码目录。
- Windows 包：`payload/tools` 目前只有 `README.md` 占位文件，没有额外工具源码目录。

需要注意：`codexbridge`、`weress`、`cc-shield` 等以 Skill/说明方式随包提供，不会默认启动后台服务，不会自动读取账号、token、cookie 或聊天记录。

`wechat-cli` 不在默认安装清单里，也不会自动安装。

## 隐私和账号边界

安装包不会预置或上传客户的 API Key、token、cookie、OAuth 登录态，也不会自动读取微信聊天记录。飞书、企业微信、CodePilot、Obsidian 等账号授权，需要客户在本机自行完成。

## 日志位置

macOS 日志：

```text
~/Downloads/Agent-Obsidian-install-logs/
```

Windows 日志：

```text
%USERPROFILE%\Downloads\Agent-Obsidian-install-logs
```

如果安装失败，把最新日志文件和交付清单回传给交付人员即可定位。
