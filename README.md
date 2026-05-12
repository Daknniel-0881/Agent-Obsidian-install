# qulv-agent-obsidian-install

曲率 AI · Agent + Obsidian + 自动化环境安装器。

当前仓库只发布 **Mac 版本**。Windows 和 Linux 版本还在测试中，测试跑通后再继续追加到这个仓库。

## 当前可用版本

| 系统 | 状态 | 说明 |
|---|---|---|
| macOS | 可用 | 当前已发布，可用一行命令安装 |
| Windows | 测试中 | 暂未发布 |
| Linux | 测试中 | 暂未发布 |

## 一行安装命令

在 Mac 的“终端”里复制粘贴下面这一行，回车运行：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh)"
```

安装过程会显示在终端窗口里。遇到 `Password:` 时，输入这台 Mac 的开机密码，输入时屏幕不会显示字符，输完回车即可。

## 安装内容

Mac 安装器会尽量自动准备：

- Apple 命令行工具
- Homebrew
- Git
- Node.js / npm
- Python 3.13
- Claude Code CLI
- Lark CLI
- CodePilot
- Obsidian
- Obsidian CLI 配置提示
- 基础 Skills
- `~/Desktop/CodePilot/Bridge`
- `~/Desktop/CodePilot/Obsidian`

## 这条命令会做什么

1. 下载最新版 `Agent-Obsidian-install-Mac.zip`。
2. 保存到 `~/Downloads/Mac系统/`。
3. 校验安装包 SHA256。
4. 解压安装包。
5. 运行 `install/install-macos.sh`。
6. 生成安装日志和交付清单。

## 安装包位置

完整 Mac 安装包放在 GitHub Release，不直接放在仓库文件里：

```text
https://github.com/Daknniel-0881/qulv-agent-obsidian-install/releases/latest
```

原因是 Mac 安装包包含 `.dmg` 离线安装文件，体积超过 GitHub 普通仓库单文件限制。

## 当前版本

- Mac 安装脚本：`2026-05-12.8`
- 安装包：`Agent-Obsidian-install-Mac.zip`
- SHA256：`2f7f6e7b831d46a75a01776c565a44482fb98225f3b94651c302e29091680724`

## 日志位置

安装日志会保存在：

```text
~/Downloads/Agent-Obsidian-install-logs
```
