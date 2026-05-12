# qulv-agent-obsidian-install

本仓库用于分发「曲率 AI · Agent + Obsidian + 自动化环境」客户安装包。

当前只发布 **Mac 版本**。Windows 和 Linux 版本还在本地测试，测试完成后再继续发布。

## Mac 一条命令安装

在 Mac 自带「终端」里复制粘贴下面整段命令，然后回车：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install-mac-from-github.sh)"
```

这条命令会自动下载仓库里的 `Mac系统` 说明和脚本，再从 GitHub Release 下载 `Agent-Obsidian-install-Mac.zip`，放到 `~/Downloads/Mac系统`，然后打开新的终端窗口开始安装。

如果 `curl` 访问 GitHub 很慢，也可以先下载本仓库 ZIP，手动解压后把 `Mac系统` 文件夹放到 `~/Downloads/Mac系统`，再打开 `Mac系统/复制到终端运行.txt`，全选复制到终端运行。

## Mac 包里有什么

| 内容 | 说明 |
|---|---|
| GitHub Release: `Agent-Obsidian-install-Mac.zip` | 真正的安装包，由一键脚本自动下载 |
| `Mac系统/复制到终端运行.txt` | 给客户复制粘贴到终端的一条安装命令 |
| `Mac系统/使用说明.txt` | 极简操作说明 |
| `Mac系统/install-macos-*.sh` | 当前版本安装脚本快照 |

说明：安装包 zip 体积超过 GitHub 普通仓库单文件限制，因此 zip 放在 GitHub Release 资产中；仓库里保留说明、脚本和一键拉取入口。

## 会自动安装什么

- Apple Command Line Tools
- Homebrew（官方源和国内镜像测速择优）
- Git
- Node.js / npm
- Python 3.13
- Claude Code CLI
- Lark CLI
- HyperFrames CLI
- 企业微信 CLI
- MarkItDown
- yt-dlp
- FFmpeg
- CodePilot
- Obsidian
- Obsidian CLI 软链
- 通用 Skills：Obsidian、Lark、文档处理、PPT/PDF/表格、Skill 创建、工具发现、前端设计、HyperFrames、Agent Reach 等

`wechat-cli` 已从默认安装清单移除。

## 不会替客户做什么

- 不预置 API Key、token、cookie、OAuth 登录态
- 不代替客户登录飞书、企业微信、Obsidian 或 CodePilot
- 不自动读取微信聊天记录
- 不自动启动 WeRSS、CodexBridge 等账号态工具
- 不把本机个人路径、私有知识库、客户资料打包进客户包

## 安装日志

安装时会弹出终端窗口显示进度。

日志保存在：

```text
~/Downloads/Agent-Obsidian-install-logs/
```

如果安装失败，把最新的 `install-macos-*.log` 和 `delivery-checklist-*.txt` 回传给交付人员即可定位。
