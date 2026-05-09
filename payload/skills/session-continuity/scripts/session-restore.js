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
        // 确保目录存在
        if (!fs.existsSync(LOGS_DIR)) {
            fs.mkdirSync(LOGS_DIR, { recursive: true });
            console.log('📋 新用户会话 - 初始化任务管理系统');
            return;
        }

        if (!fs.existsSync(PROJECTS_FILE)) {
            console.log('📋 新会话 - 暂无活跃项目');
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

        // 按优先级排序
        const priorityOrder = { 'high': 3, 'medium': 2, 'low': 1 };
        projects.sort((a, b) => {
            return (priorityOrder[b.priority] || 0) - (priorityOrder[a.priority] || 0);
        });

        projects.forEach(project => {
            const priorityIcon = project.priority === 'high' ? '🔥' :
                                project.priority === 'medium' ? '🔸' : '🔹';

            console.log(`${priorityIcon} ${project.name} (${project.priority})`);
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

        // 显示最近更新时间
        if (data.last_updated) {
            const lastUpdate = new Date(data.last_updated).toLocaleString('zh-CN');
            console.log(`\n📅 最后更新: ${lastUpdate}`);
        }

    } catch (error) {
        console.error('会话恢复失败:', error.message);
        console.log('尝试从备份恢复或手动检查配置文件');
    }
}

if (require.main === module) {
    restoreSession();
}

module.exports = { restoreSession };