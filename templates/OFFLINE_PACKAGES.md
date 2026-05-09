# 离线安装包放置规范

建议把客户电脑需要的离线环境包统一放进：

```text
自动部署脚本/离线安装包/
```

脚本会先搜索这个目录，找到离线包就直接安装；找不到才回退到 Homebrew、winget、apt/dnf/pacman 或 npm 在线安装。

## 推荐目录结构

```text
自动部署脚本/
├── Mac系统/
│   ├── CodePilot-0.54.0-arm64.dmg
│   ├── CodePilot-0.54.0-x64.dmg
│   └── Obsidian-1.12.7.dmg
├── Win系统/
│   ├── CodePilot.Setup.0.54.0.exe
│   └── Obsidian-1.12.7.exe
├── Linux系统/
│   ├── CodePilot-0.54.0-amd64.deb
│   ├── CodePilot-0.54.0-arm64.deb
│   └── obsidian_1.12.7_amd64.deb
└── 离线安装包/
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

## 文件命名

脚本按下面通配符搜索：

| 软件 | macOS | Windows | Linux |
|---|---|---|---|
| Git | `git-*.pkg` / `Git-*.pkg` | `Git-*.exe` | `linux-*/git/*.deb` |
| Node.js | `node-*-darwin-*.pkg` | `node-v*-x64.msi` | `linux-*/node/*.deb` |
| Claude Code | `anthropic-ai-claude-code-*.tgz` / `claude-code-*.tgz` | 同左 | 同左 |
| Lark CLI | `larksuite-cli-*.tgz` / `lark-cli-*.tgz` | 同左 | 同左 |

## 生成 npm 离线包

在一台网络正常的电脑上执行：

```bash
npm pack @anthropic-ai/claude-code
npm pack @larksuite/cli
```

把生成的 `.tgz` 文件放到：

```text
自动部署脚本/离线安装包/npm/
```

客户电脑上脚本会自动执行：

```bash
npm install -g <本地 tgz 文件>
```

## 注意

- 离线包不要包含 API Key、token、appSecret。
- 飞书 CLI 只安装命令行工具，不预填应用配置，也不代替客户授权。
- CodePilot API Key 由客户在 CodePilot 左下角 `[设置]` -> `[服务商]` 中自行填写。
