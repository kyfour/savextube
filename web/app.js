// SaveXTube Web 下载前端脚本

// 当前任务状态
let currentTaskId = null;
let progressInterval = null;

// DOM 元素
const downloadForm = document.getElementById('downloadForm');
const urlInput = document.getElementById('urlInput');
const downloadBtn = document.getElementById('downloadBtn');
const btnText = downloadBtn.querySelector('.btn-text');
const btnLoader = downloadBtn.querySelector('.btn-loader');

const statusSection = document.getElementById('statusSection');
const errorSection = document.getElementById('errorSection');
const successSection = document.getElementById('successSection');

const taskTitle = document.getElementById('taskTitle');
const taskStatus = document.getElementById('taskStatus');
const taskProgress = document.getElementById('taskProgress');
const taskSpeed = document.getElementById('taskSpeed');
const taskETA = document.getElementById('taskETA');
const progressBar = document.getElementById('progressBar');

const errorText = document.getElementById('errorText');
const successDetails = document.getElementById('successDetails');

const taskList = document.getElementById('taskList');
const toggleOptionsBtn = document.getElementById('toggleOptions');
const advancedOptions = document.getElementById('advancedOptions');

// 高级选项切换
if (toggleOptionsBtn) {
    toggleOptionsBtn.addEventListener('click', () => {
        const isVisible = advancedOptions.style.display !== 'none';
        advancedOptions.style.display = isVisible ? 'none' : 'block';
        toggleOptionsBtn.textContent = isVisible ? '高级选项 ▼' : '高级选项 ▲';
    });
}

// 表单提交处理
if (downloadForm) {
    downloadForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const url = urlInput.value.trim();
        if (!url) {
            showError('请输入有效的链接');
            return;
        }
        
        // 获取高级选项
        const quality = document.getElementById('quality')?.value || 'best';
        const format = document.getElementById('format')?.value || 'auto';
        
        await startDownload(url, quality, format);
    });
}

// 开始下载
async function startDownload(url, quality, format) {
    // 重置状态
    hideAllSections();
    setButtonLoading(true);
    
    try {
        const response = await fetch('/api/download', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                url: url,
                quality: quality,
                format: format
            })
        });
        
        const data = await response.json();
        
        if (!response.ok || !data.ok) {
            throw new Error(data.error || '下载请求失败');
        }
        
        currentTaskId = data.task_id;
        
        // 显示进度区域
        statusSection.style.display = 'block';
        taskTitle.textContent = data.title || '准备下载...';
        taskStatus.textContent = '准备中';
        
        // 开始轮询进度
        startProgressPolling();
        
        // 添加到历史记录
        addToHistory(data.task_id, url);
        
    } catch (error) {
        console.error('下载失败:', error);
        showError(error.message || '下载失败，请重试');
        setButtonLoading(false);
    }
}

// 开始轮询进度
function startProgressPolling() {
    if (progressInterval) {
        clearInterval(progressInterval);
    }
    
    // 立即查询一次
    updateProgress();
    
    // 每2秒查询一次
    progressInterval = setInterval(updateProgress, 2000);
}

// 停止轮询进度
function stopProgressPolling() {
    if (progressInterval) {
        clearInterval(progressInterval);
        progressInterval = null;
    }
}

// 更新进度
async function updateProgress() {
    if (!currentTaskId) return;
    
    try {
        const response = await fetch(`/api/progress/${currentTaskId}`);
        const data = await response.json();
        
        if (!response.ok || !data.ok) {
            throw new Error(data.error || '获取进度失败');
        }
        
        const progress = data.progress;
        
        // 更新UI
        taskTitle.textContent = progress.title || '下载中...';
        taskStatus.textContent = getStatusText(progress.status);
        
        if (progress.percent !== undefined) {
            const percent = Math.min(100, Math.max(0, progress.percent));
            taskProgress.textContent = `${percent.toFixed(1)}%`;
            progressBar.style.width = `${percent}%`;
        }
        
        if (progress.speed) {
            taskSpeed.textContent = formatSpeed(progress.speed);
        }
        
        if (progress.eta) {
            taskETA.textContent = formatETA(progress.eta);
        }
        
        // 检查是否完成
        if (progress.status === 'finished') {
            stopProgressPolling();
            showSuccess(progress);
            setButtonLoading(false);
            urlInput.value = '';
        } else if (progress.status === 'error') {
            stopProgressPolling();
            showError(progress.error || '下载失败');
            setButtonLoading(false);
        }
        
    } catch (error) {
        console.error('更新进度失败:', error);
        // 不要立即停止轮询，可能是临时网络问题
    }
}

// 获取状态文本
function getStatusText(status) {
    const statusMap = {
        'pending': '等待中',
        'downloading': '下载中',
        'processing': '处理中',
        'finished': '已完成',
        'error': '失败'
    };
    return statusMap[status] || status;
}

// 格式化速度
function formatSpeed(bytesPerSecond) {
    if (!bytesPerSecond || bytesPerSecond === 0) return '0 MB/s';
    
    const mbps = bytesPerSecond / (1024 * 1024);
    if (mbps >= 1) {
        return `${mbps.toFixed(2)} MB/s`;
    } else {
        const kbps = bytesPerSecond / 1024;
        return `${kbps.toFixed(2)} KB/s`;
    }
}

// 格式化预计时间
function formatETA(seconds) {
    if (!seconds || seconds <= 0) return '--:--';
    
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    
    if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    } else {
        return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
}

// 显示错误
function showError(message) {
    hideAllSections();
    errorSection.style.display = 'block';
    errorText.textContent = message;
}

// 显示成功
function showSuccess(progress) {
    hideAllSections();
    successSection.style.display = 'block';
    
    let details = `文件名: ${progress.filename || '未知'}\n`;
    if (progress.filesize) {
        const sizeMB = progress.filesize / (1024 * 1024);
        details += `文件大小: ${sizeMB.toFixed(2)} MB\n`;
    }
    if (progress.quality) {
        details += `质量: ${progress.quality}\n`;
    }
    details += `保存路径: ${progress.path || '服务器配置目录'}`;
    
    successDetails.textContent = details;
}

// 隐藏所有状态区域
function hideAllSections() {
    statusSection.style.display = 'none';
    errorSection.style.display = 'none';
    successSection.style.display = 'none';
}

// 设置按钮加载状态
function setButtonLoading(loading) {
    if (loading) {
        btnText.style.display = 'none';
        btnLoader.style.display = 'inline-block';
        downloadBtn.disabled = true;
    } else {
        btnText.style.display = 'inline';
        btnLoader.style.display = 'none';
        downloadBtn.disabled = false;
    }
}

// 添加到历史记录
function addToHistory(taskId, url) {
    // 从 localStorage 获取历史记录
    let history = [];
    try {
        const stored = localStorage.getItem('downloadHistory');
        if (stored) {
            history = JSON.parse(stored);
        }
    } catch (e) {
        console.error('读取历史记录失败:', e);
    }
    
    // 添加新记录
    history.unshift({
        id: taskId,
        url: url,
        time: new Date().toISOString(),
        status: 'downloading'
    });
    
    // 只保留最近20条
    history = history.slice(0, 20);
    
    // 保存
    try {
        localStorage.setItem('downloadHistory', JSON.stringify(history));
    } catch (e) {
        console.error('保存历史记录失败:', e);
    }
    
    // 更新显示
    renderHistory();
}

// 渲染历史记录
function renderHistory() {
    let history = [];
    try {
        const stored = localStorage.getItem('downloadHistory');
        if (stored) {
            history = JSON.parse(stored);
        }
    } catch (e) {
        console.error('读取历史记录失败:', e);
    }
    
    if (history.length === 0) {
        taskList.innerHTML = '<p class="empty-message">暂无下载记录</p>';
        return;
    }
    
    taskList.innerHTML = history.map(item => {
        const date = new Date(item.time);
        const timeStr = date.toLocaleString('zh-CN');
        
        return `
            <div class="task-card">
                <div class="task-header">
                    <span class="task-title">${truncateUrl(item.url)}</span>
                    <span class="task-status">${getStatusText(item.status)}</span>
                </div>
                <div class="task-details">
                    <span>${timeStr}</span>
                </div>
            </div>
        `;
    }).join('');
}

// 截断URL显示
function truncateUrl(url, maxLength = 50) {
    if (url.length <= maxLength) return url;
    return url.substring(0, maxLength - 3) + '...';
}

// 页面加载时渲染历史记录
if (taskList) {
    renderHistory();
}

// 页面卸载时清理
window.addEventListener('beforeunload', () => {
    stopProgressPolling();
});
