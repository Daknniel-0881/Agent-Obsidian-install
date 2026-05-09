# 人工设置清单

脚本结束后，交付人员按下面顺序检查。

## 1. 打开 CodePilot

### macOS

如果提示“无法验证开发者”：

1. 打开“系统设置”
2. 进入“隐私与安全性”
3. 找到 CodePilot 的阻止提示
4. 点击“仍要打开”
5. 输入电脑密码
6. 再次打开 CodePilot

不要默认用脚本绕过 Gatekeeper。只有在客户明确授权、并确认安装包来源可信时，才考虑移除 quarantine 属性。

### Windows

如果出现 SmartScreen：

1. 点击“更多信息”
2. 点击“仍要运行”
3. 按提示完成安装

## 2. 配置 CodePilot 和 Claude Code

1. 在 CodePilot 里打开工作目录。
2. 点击左下角 `[设置]`。
3. 选择 `[服务商]`。
4. 选择客户实际使用的服务商类型。
5. 由客户自己填写 API Key。
6. 保存并测试连接。
7. 确认 Claude Code 能正常启动。
8. 让 Claude Code 读取当前工作区的 `CLAUDE.md`。

## 3. 创建或打开 Obsidian vault

默认路径：

- macOS：`~/Desktop/CodePilot/Obsidian/ClaudeCode`
- Windows：优先 `D:\CodePilot\Obsidian\ClaudeCode`
- Linux：`~/CodePilot/Obsidian/ClaudeCode`

在 Obsidian 中选择“打开本地文件夹作为仓库”，指向这个目录。

## 4. 开启 Obsidian CLI

1. 打开 Obsidian。
2. 点击左下角齿轮设置。
3. 找到“关于”或“通用”相关页面。
4. 滑到最底部的“高级”区域。
5. 打开“命令行界面”。
6. 弹窗出现后点击“注册”。
7. 回到终端执行：

```bash
obsidian help
```

能看到帮助信息就说明 CLI 已经可用。

## 5. 配置 Lark CLI

脚本只安装 Lark CLI，不预填飞书应用配置，不写入 appSecret，不代替客户授权。

客户首次使用飞书能力时，自己运行：

```bash
lark-cli config init --new
```

客户需要用自己的身份访问云文档、日历、任务时，再按最小权限授权：

```bash
lark-cli auth login --scope "<需要的 scope>"
```

不要把 appSecret 或 token 写进公开模板。

## 6. 验证知识库规则

在 CodePilot 里让 Claude Code 执行一次：

```text
请创建一条测试笔记，保存到知识库的 00-Inbox，标题为“部署验证测试”。
```

然后检查 Obsidian vault 里是否出现对应 Markdown 文件。
