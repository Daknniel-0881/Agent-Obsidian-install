# qulv-agent-obsidian-install

曲率 AI 的 Mac 一键安装包。

## 一行安装命令

在 Mac 的“终端”里复制粘贴下面这一行，回车运行：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh)"
```

安装过程会显示在终端窗口里。遇到 `Password:` 时，输入这台 Mac 的开机密码，输入时屏幕不会显示字符，输完回车即可。

## 这条命令会做什么

1. 下载最新版 `Agent-Obsidian-install-Mac.zip`。
2. 保存到 `~/Downloads/Mac系统/`。
3. 校验安装包 SHA256。
4. 解压安装包。
5. 运行 `install/install-macos.sh`。
6. 生成安装日志和交付清单。

## 当前版本

- Mac 安装脚本：`2026-05-12.8`
- 安装包：`Agent-Obsidian-install-Mac.zip`
- SHA256：`2f7f6e7b831d46a75a01776c565a44482fb98225f3b94651c302e29091680724`

## 日志位置

安装日志会保存在：

```text
~/Downloads/Agent-Obsidian-install-logs
```

