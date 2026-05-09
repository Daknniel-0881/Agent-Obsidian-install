---
name: session-continuity
description: Session memory and task continuity management. Use at session start to restore context, when user says "记住这个", "更新任务状态", "生成交接文档", or when context approaches limits. Essential for maintaining task continuity across sessions and preventing work from falling through cracks.
---

# Session Continuity Management

智能会话记忆和任务连续性管理系统，确保工作不中断，上下文不丢失。

## 核心功能

### 1. 会话启动恢复
每次新会话开始时：
- 读取当前活跃项目状态
- 显示未完成任务和优先级
- 提供上一次会话的关键上下文
- 建议下一步行动

### 2. 任务状态管理
- 实时更新项目进展
- 记录重要决策和变更
- 追踪阻塞问题和解决方案
- 维护任务优先级队列

### 3. 专业交接文档生成
基于7段式模板：
- 当前任务目标
- 当前进展
- 关键上下文
- 关键发现
- 未完成事项
- 建议接手路径
- 风险与注意事项

### 4. 与现有系统协作
- **Claude-mem**: 技术上下文和工具使用
- **Obsidian**: 知识库和长期记忆
- **MemCell**: 结构化记忆片段

## 使用场景

### 自动触发
- 新会话开始（会话恢复）
- 上下文接近token限制（生成handoff）
- 检测到重要决策或里程碑

### 手动触发
- 用户说"记住这个"、"记一下"
- "更新任务状态"、"项目进展"
- "生成交接文档"、"handoff"
- "今天做了什么"、"明天要做什么"

## 操作指南

### 会话启动时
```markdown
## 📋 当前任务状态
**活跃项目**: [项目列表]
**今日优先级**: [任务列表]
**上次进展**: [关键更新]
**需要关注**: [阻塞点或重要事项]
```

### 任务更新时
1. 读取当前状态文件
2. 更新相关项目进展
3. 记录时间戳和决策理由
4. 保存到日志文件

### 生成Handoff时
严格按照7段式结构：

```markdown
# {YYMMDD}-handoff.md

## 1. 当前任务目标
说明当前要解决的问题、预期产出和完成标准。

## 2. 当前进展
说明目前已经完成了哪些分析、确认、修改、排查、讨论或产出。

## 3. 关键上下文
包括但不限于：
- 重要背景信息
- 用户的明确要求
- 已知约束
- 已做出的关键决定
- 重要假设

## 4. 关键发现
列出目前最重要的结论、规律、异常点、根因判断、设计判断或值得注意的信息。

## 5. 未完成事项
列出仍需要继续处理的内容，并按优先级排序。

## 6. 建议接手路径
告诉下一位 Agent：
- 应优先查看哪些文件、模块、数据、日志、命令、页面或线索
- 应先验证什么
- 推荐的下一步动作是什么

## 7. 风险与注意事项
说明哪些点容易误判、重复劳动或跑偏，哪些方向已经验证过且不建议继续。

## 下一位 Agent 的第一步建议
[具体可执行的第一步建议]
```

## 文件组织结构

```
~/.claude/session-logs/
├── active-projects.json          # 活跃项目状态
├── 2026-03-16-tasks.md          # 每日任务日志
├── handoffs/
│   ├── 260316-handoff-01.md     # 交接文档
│   └── 260316-handoff-02.md
└── archive/
    └── 2026-03/                 # 月度归档
```

## 状态文件格式

### active-projects.json
```json
{
  "last_updated": "2026-03-16T10:30:00+08:00",
  "projects": [
    {
      "id": "agent-skills",
      "name": "Agent Skills开发",
      "status": "in_progress",
      "priority": "high",
      "last_activity": "创建session-continuity skill",
      "next_actions": ["测试skill功能", "完善文档"],
      "blockers": []
    },
    {
      "id": "knowledge-base",
      "name": "知识库优化",
      "status": "ongoing",
      "priority": "medium",
      "last_activity": "收录Claude Code实践指南",
      "next_actions": ["整理工具索引", "建立双向链接"],
      "blockers": []
    }
  ],
  "daily_focus": [
    "完成session-continuity skill",
    "测试claude-mem集成",
    "优化工作流程"
  ]
}
```

### 日志文件格式 (YYYY-MM-DD-tasks.md)
```markdown
# 2026-03-16 任务日志

## 🎯 今日目标
- [ ] 创建session-continuity skill
- [ ] 安装claude-mem插件
- [ ] 测试会话记忆功能

## ⚡ 重要进展
### 10:30 - Claude-mem安装成功
- 通过安全审查，35k+ stars项目
- 功能：跨会话上下文压缩和恢复
- Token节省机制：3层渐进披露

### 11:00 - Session-continuity设计完成
- 7段式handoff模板集成
- 与claude-mem形成互补
- 专注任务管理和业务连续性

## 🔍 关键决策
- claude-mem处理技术上下文
- session-continuity处理任务管理
- 两者协作而非重复

## ⚠️ 注意事项
- 需要重启Claude Code激活claude-mem
- 文件操作需要安全备份原则
- 保持工具间的清晰边界

## 📋 明日计划
- [ ] 测试完整工作流程
- [ ] 优化skill触发机制
- [ ] 文档完善和示例
```

## 执行脚本

### scripts/session-restore.js
```javascript
#!/usr/bin/env node
/**
 * 会话启动时的状态恢复脚本
 */
const fs = require('fs');
const path = require('path');

const LOGS_DIR = path.join(process.env.HOME, '.claude', 'session-logs');
const PROJECTS_FILE = path.join(LOGS_DIR, 'active-projects.json');

function restoreSession() {
    try {
        if (!fs.existsSync(PROJECTS_FILE)) {
            console.log('📋 新用户会话 - 初始化任务管理系统');
            return;
        }

        const data = JSON.parse(fs.readFileSync(PROJECTS_FILE, 'utf8'));
        const projects = data.projects.filter(p => p.status !== 'completed');

        console.log('📋 会话恢复 - 当前状态');
        console.log('================');

        if (projects.length === 0) {
            console.log('✨ 无活跃项目 - 可以开始新任务');
            return;
        }

        projects.forEach(project => {
            console.log(`🔸 ${project.name} (${project.priority})`);
            console.log(`   状态: ${project.status}`);
            console.log(`   最后活动: ${project.last_activity}`);
            if (project.next_actions.length > 0) {
                console.log(`   下一步: ${project.next_actions[0]}`);
            }
            if (project.blockers.length > 0) {
                console.log(`   ⚠️  阻塞: ${project.blockers.join(', ')}`);
            }
            console.log('');
        });

        if (data.daily_focus && data.daily_focus.length > 0) {
            console.log('🎯 今日重点:');
            data.daily_focus.forEach((item, idx) => {
                console.log(`   ${idx + 1}. ${item}`);
            });
        }

    } catch (error) {
        console.error('会话恢复失败:', error.message);
    }
}

if (require.main === module) {
    restoreSession();
}

module.exports = { restoreSession };
```

### scripts/update-task.js
```javascript
#!/usr/bin/env node
/**
 * 任务状态更新脚本
 */
const fs = require('fs');
const path = require('path');

const LOGS_DIR = path.join(process.env.HOME, '.claude', 'session-logs');
const PROJECTS_FILE = path.join(LOGS_DIR, 'active-projects.json');

function updateTask(projectId, updates) {
    try {
        // 确保目录存在
        if (!fs.existsSync(LOGS_DIR)) {
            fs.mkdirSync(LOGS_DIR, { recursive: true });
        }

        // 读取现有数据
        let data = { projects: [], daily_focus: [] };
        if (fs.existsSync(PROJECTS_FILE)) {
            data = JSON.parse(fs.readFileSync(PROJECTS_FILE, 'utf8'));
        }

        // 查找项目
        let project = data.projects.find(p => p.id === projectId);

        if (!project) {
            // 创建新项目
            project = {
                id: projectId,
                name: updates.name || projectId,
                status: 'in_progress',
                priority: 'medium',
                last_activity: '',
                next_actions: [],
                blockers: []
            };
            data.projects.push(project);
        }

        // 更新项目
        Object.assign(project, updates);
        project.last_updated = new Date().toISOString();
        data.last_updated = project.last_updated;

        // 保存数据
        fs.writeFileSync(PROJECTS_FILE, JSON.stringify(data, null, 2));

        console.log(`✅ 项目 "${project.name}" 状态已更新`);

    } catch (error) {
        console.error('任务更新失败:', error.message);
    }
}

// CLI调用
if (require.main === module) {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.log('用法: node update-task.js <project_id> <updates_json>');
        process.exit(1);
    }

    const projectId = args[0];
    const updates = JSON.parse(args[1]);
    updateTask(projectId, updates);
}

module.exports = { updateTask };
```

## 最佳实践

### 1. 每日工作流程
- **开始**: 自动显示任务状态，设定今日目标
- **进行中**: 及时更新重要进展和决策
- **结束**: 记录完成情况，规划明日重点

### 2. 项目管理
- **状态追踪**: in_progress, blocked, pending, completed
- **优先级**: high, medium, low
- **时间记录**: 所有更新带时间戳

### 3. 交接文档
- **触发时机**: 上下文>150K tokens 或会话>2小时
- **内容原则**: 具体、可执行、有价值
- **格式标准**: 严格遵循7段式结构

### 4. 数据管理
- **备份策略**: 每月自动归档
- **文件安全**: 操作前备份，批量处理前测试
- **隐私保护**: 敏感信息标记和过滤

## 与其他系统协作

### Claude-mem集成
- **分工**: claude-mem处理技术上下文，session-continuity处理任务管理
- **数据流**: 从claude-mem的观察中提取任务相关信息
- **触发协调**: 避免重复触发和冲突

### Obsidian集成
- **知识链接**: 任务日志引用相关知识库文档
- **双向更新**: 重要决策同步到Obsidian
- **搜索支持**: 支持跨系统的任务历史搜索

### MemCell协作
- **记忆类型**: 利用episode、foresight、event分类
- **自动聚类**: 任务相关的MemCell自动关联
- **画像更新**: 工作模式变化更新PROFILE.md

## 注意事项

1. **文件安全**: 所有文件操作遵循安全备份原则
2. **性能优化**: 避免频繁读写，使用缓存机制
3. **隐私保护**: 支持`<private>`标签排除敏感内容
4. **可扩展性**: 模块化设计，便于功能扩展
5. **容错机制**: 文件损坏时自动恢复到备份版本

## 故障排除

### 常见问题
- **文件权限**: 确保~/.claude/session-logs/可写
- **JSON格式**: 状态文件损坏时使用备份恢复
- **脚本执行**: Node.js环境检查和依赖安装
- **编码问题**: 统一使用UTF-8编码

### 恢复策略
- **自动备份**: 每次更新前备份上一版本
- **手动恢复**: 从archive/目录恢复历史版本
- **重建索引**: 从日志文件重建项目状态