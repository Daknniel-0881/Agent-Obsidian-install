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
        let data = {
            projects: [],
            daily_focus: [],
            last_updated: new Date().toISOString()
        };

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
                blockers: [],
                created_at: new Date().toISOString()
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

        return project;

    } catch (error) {
        console.error('任务更新失败:', error.message);
        throw error;
    }
}

function getTodaysLog() {
    const today = new Date().toISOString().split('T')[0];
    return path.join(LOGS_DIR, `${today}-tasks.md`);
}

function addDailyLogEntry(entry) {
    try {
        const logFile = getTodaysLog();
        const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false });

        let content = '';
        if (fs.existsSync(logFile)) {
            content = fs.readFileSync(logFile, 'utf8');
        } else {
            // 创建新的日志文件
            const today = new Date().toLocaleDateString('zh-CN');
            content = `# ${today} 任务日志

## 🎯 今日目标
- [ ]

## ⚡ 重要进展

## 🔍 关键决策

## ⚠️ 注意事项

## 📋 明日计划
- [ ]

`;
        }

        // 在"重要进展"部分添加新条目
        const newEntry = `### ${timestamp} - ${entry}\n`;
        const progressSection = '## ⚡ 重要进展\n';

        if (content.includes(progressSection)) {
            content = content.replace(
                progressSection,
                progressSection + newEntry
            );
        } else {
            content += '\n' + progressSection + newEntry;
        }

        fs.writeFileSync(logFile, content);
        console.log(`📝 日志已更新: ${entry}`);

    } catch (error) {
        console.error('日志更新失败:', error.message);
    }
}

function generateHandoff(context) {
    try {
        const now = new Date();
        const dateStr = now.toISOString().split('T')[0].replace(/-/g, '').substring(2); // YYMMDD
        const timeStr = now.toLocaleTimeString('zh-CN', { hour12: false, hour: '2-digit', minute: '2-digit' });

        const handoffsDir = path.join(LOGS_DIR, 'handoffs');
        if (!fs.existsSync(handoffsDir)) {
            fs.mkdirSync(handoffsDir, { recursive: true });
        }

        const filename = `${dateStr}-handoff-${timeStr.replace(':', '')}.md`;
        const filepath = path.join(handoffsDir, filename);

        const template = `# ${dateStr}-handoff.md

## 1. 当前任务目标
${context.goals || '说明当前要解决的问题、预期产出和完成标准。'}

## 2. 当前进展
${context.progress || '说明目前已经完成了哪些分析、确认、修改、排查、讨论或产出。'}

## 3. 关键上下文
${context.context || `包括但不限于：
- 重要背景信息
- 用户的明确要求
- 已知约束
- 已做出的关键决定
- 重要假设`}

## 4. 关键发现
${context.findings || '列出目前最重要的结论、规律、异常点、根因判断、设计判断或值得注意的信息。'}

## 5. 未完成事项
${context.todos || '列出仍需要继续处理的内容，并按优先级排序。'}

## 6. 建议接手路径
${context.recommendations || `告诉下一位 Agent：
- 应优先查看哪些文件、模块、数据、日志、命令、页面或线索
- 应先验证什么
- 推荐的下一步动作是什么`}

## 7. 风险与注意事项
${context.risks || '说明哪些点容易误判、重复劳动或跑偏，哪些方向已经验证过且不建议继续。'}

## 下一位 Agent 的第一步建议
${context.next_step || '具体可执行的第一步建议'}

---
生成时间: ${now.toLocaleString('zh-CN')}
`;

        fs.writeFileSync(filepath, template);
        console.log(`📋 Handoff文档已生成: ${filepath}`);

        return filepath;

    } catch (error) {
        console.error('Handoff生成失败:', error.message);
        throw error;
    }
}

// CLI调用
if (require.main === module) {
    const args = process.argv.slice(2);
    const command = args[0];

    switch (command) {
        case 'update':
            if (args.length < 3) {
                console.log('用法: node update-task.js update <project_id> <updates_json>');
                process.exit(1);
            }
            const projectId = args[1];
            const updates = JSON.parse(args[2]);
            updateTask(projectId, updates);
            break;

        case 'log':
            if (args.length < 2) {
                console.log('用法: node update-task.js log <entry_text>');
                process.exit(1);
            }
            const entry = args.slice(1).join(' ');
            addDailyLogEntry(entry);
            break;

        case 'handoff':
            if (args.length < 2) {
                console.log('用法: node update-task.js handoff <context_json>');
                process.exit(1);
            }
            const context = JSON.parse(args[1]);
            generateHandoff(context);
            break;

        default:
            console.log('可用命令: update, log, handoff');
            console.log('用法示例:');
            console.log('  node update-task.js update "project1" \'{"name":"测试项目","status":"in_progress"}\'');
            console.log('  node update-task.js log "完成了重要功能"');
            console.log('  node update-task.js handoff \'{"goals":"完成测试","progress":"已完成50%"}\'');
            process.exit(1);
    }
}

module.exports = {
    updateTask,
    addDailyLogEntry,
    generateHandoff,
    getTodaysLog
};