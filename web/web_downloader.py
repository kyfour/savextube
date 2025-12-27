#!/usr/bin/env python3
"""
SaveXTube 网页下载 API 服务
提供 Web 界面的下载功能
"""

import os
import sys
import json
import uuid
import time
import logging
import threading
from pathlib import Path
from flask import Blueprint, jsonify, request, send_from_directory
from typing import Dict, Any, Optional

# 设置日志
logger = logging.getLogger(__name__)

# 全局任务存储
download_tasks: Dict[str, Dict[str, Any]] = {}
tasks_lock = threading.Lock()


class DownloadTask:
    """下载任务类"""
    
    def __init__(self, task_id: str, url: str, quality: str = 'best', format: str = 'auto'):
        self.task_id = task_id
        self.url = url
        self.quality = quality
        self.format = format
        self.status = 'pending'
        self.percent = 0.0
        self.speed = 0.0
        self.eta = 0
        self.title = '准备中...'
        self.filename = ''
        self.filesize = 0
        self.path = ''
        self.error = None
        self.created_at = time.time()
        self.updated_at = time.time()
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'task_id': self.task_id,
            'url': self.url,
            'quality': self.quality,
            'format': self.format,
            'status': self.status,
            'percent': self.percent,
            'speed': self.speed,
            'eta': self.eta,
            'title': self.title,
            'filename': self.filename,
            'filesize': self.filesize,
            'path': self.path,
            'error': self.error,
            'created_at': self.created_at,
            'updated_at': self.updated_at
        }
    
    def update_progress(self, **kwargs):
        """更新进度"""
        for key, value in kwargs.items():
            if hasattr(self, key):
                setattr(self, key, value)
        self.updated_at = time.time()


def create_downloader_blueprint(downloader=None) -> Blueprint:
    """创建下载器蓝图"""
    bp = Blueprint("web_downloader", __name__, url_prefix="")
    
    # 存储下载器实例的引用
    _downloader = downloader
    
    def get_downloader():
        """获取下载器实例"""
        nonlocal _downloader
        if _downloader is None:
            # 尝试从 Flask app 中获取
            from flask import current_app
            if hasattr(current_app, '_bot_instance'):
                bot_instance = current_app._bot_instance
                if hasattr(bot_instance, 'downloader'):
                    _downloader = bot_instance.downloader
                    logger.info("✅ 从 Flask app 获取到下载器实例")
        return _downloader
    
    @bp.route('/')
    def index():
        """主页"""
        return send_from_directory('web', 'index.html')
    
    @bp.route('/download')
    def download_page():
        """下载页面"""
        return send_from_directory('web', 'download.html')
    
    @bp.post('/api/download')
    def api_download():
        """提交下载任务"""
        try:
            data = request.get_json() or {}
            url = data.get('url', '').strip()
            quality = data.get('quality', 'best')
            format_type = data.get('format', 'auto')
            
            if not url:
                return jsonify({'ok': False, 'error': '请提供有效的链接'}), 400
            
            # 创建任务
            task_id = str(uuid.uuid4())
            task = DownloadTask(task_id, url, quality, format_type)
            
            with tasks_lock:
                download_tasks[task_id] = task
            
            logger.info(f"📥 创建下载任务: {task_id} - {url}")
            
            # 在后台线程中执行下载
            thread = threading.Thread(
                target=execute_download,
                args=(task_id, url, quality, format_type),
                daemon=True
            )
            thread.start()
            
            return jsonify({
                'ok': True,
                'task_id': task_id,
                'title': task.title,
                'message': '任务已创建'
            })
            
        except Exception as e:
            logger.error(f"❌ 创建下载任务失败: {e}", exc_info=True)
            return jsonify({'ok': False, 'error': str(e)}), 500
    
    @bp.get('/api/progress/<task_id>')
    def api_progress(task_id: str):
        """查询下载进度"""
        try:
            with tasks_lock:
                task = download_tasks.get(task_id)
            
            if not task:
                return jsonify({'ok': False, 'error': '任务不存在'}), 404
            
            return jsonify({
                'ok': True,
                'progress': task.to_dict()
            })
            
        except Exception as e:
            logger.error(f"❌ 查询进度失败: {e}", exc_info=True)
            return jsonify({'ok': False, 'error': str(e)}), 500
    
    @bp.get('/api/tasks')
    def api_tasks():
        """获取所有任务"""
        try:
            with tasks_lock:
                tasks = [task.to_dict() for task in download_tasks.values()]
            
            # 按创建时间倒序排列
            tasks.sort(key=lambda x: x['created_at'], reverse=True)
            
            return jsonify({
                'ok': True,
                'tasks': tasks
            })
            
        except Exception as e:
            logger.error(f"❌ 获取任务列表失败: {e}", exc_info=True)
            return jsonify({'ok': False, 'error': str(e)}), 500
    
    @bp.post('/api/cancel/<task_id>')
    def api_cancel(task_id: str):
        """取消下载任务"""
        try:
            with tasks_lock:
                task = download_tasks.get(task_id)
            
            if not task:
                return jsonify({'ok': False, 'error': '任务不存在'}), 404
            
            # 标记为已取消
            task.update_progress(status='cancelled', error='用户取消')
            
            logger.info(f"🚫 取消下载任务: {task_id}")
            
            return jsonify({
                'ok': True,
                'message': '任务已取消'
            })
            
        except Exception as e:
            logger.error(f"❌ 取消任务失败: {e}", exc_info=True)
            return jsonify({'ok': False, 'error': str(e)}), 500
    
    def execute_download(task_id: str, url: str, quality: str, format_type: str):
        """执行下载任务"""
        with tasks_lock:
            task = download_tasks.get(task_id)
        
        if not task:
            logger.error(f"❌ 任务不存在: {task_id}")
            return
        
        try:
            downloader = get_downloader()
            if not downloader:
                raise Exception("下载器未初始化")
            
            task.update_progress(status='downloading', title='正在下载...')
            logger.info(f"🚀 开始下载: {url}")
            
            # 创建进度回调
            def progress_hook(d):
                """yt-dlp 进度回调"""
                try:
                    if d['status'] == 'downloading':
                        # 更新进度
                        percent = 0.0
                        if d.get('total_bytes'):
                            percent = (d.get('downloaded_bytes', 0) / d['total_bytes']) * 100
                        elif d.get('total_bytes_estimate'):
                            percent = (d.get('downloaded_bytes', 0) / d['total_bytes_estimate']) * 100
                        
                        speed = d.get('speed', 0) or 0
                        eta = d.get('eta', 0) or 0
                        filename = d.get('filename', '')
                        
                        task.update_progress(
                            status='downloading',
                            percent=percent,
                            speed=speed,
                            eta=eta,
                            filename=os.path.basename(filename) if filename else ''
                        )
                        
                    elif d['status'] == 'finished':
                        filename = d.get('filename', '')
                        task.update_progress(
                            status='processing',
                            percent=95.0,
                            filename=os.path.basename(filename) if filename else '',
                            title='处理中...'
                        )
                        
                except Exception as e:
                    logger.warning(f"⚠️ 进度回调错误: {e}")
            
            # 配置 yt-dlp 选项
            ydl_opts = {
                'quiet': False,
                'no_warnings': False,
                'progress_hooks': [progress_hook],
            }
            
            # 根据格式类型设置选项
            if format_type == 'mp3':
                ydl_opts['format'] = 'bestaudio/best'
                ydl_opts['postprocessors'] = [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'mp3',
                    'preferredquality': '320',
                }]
            elif format_type == 'mp4':
                if quality == 'best':
                    ydl_opts['format'] = 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'
                else:
                    ydl_opts['format'] = f'bestvideo[height<={quality.replace("p", "")}][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'
            else:
                # 自动检测
                ydl_opts['format'] = 'best'
            
            # 检测平台并使用对应的下载方法
            import yt_dlp
            
            # 设置下载路径
            download_path = downloader.download_path
            
            # 检测平台
            if 'youtube.com' in url or 'youtu.be' in url:
                ydl_opts['outtmpl'] = os.path.join(download_path, 'YouTube', '%(title)s.%(ext)s')
                task.update_progress(title='YouTube 下载')
            elif 'bilibili.com' in url:
                ydl_opts['outtmpl'] = os.path.join(download_path, 'Bilibili', '%(title)s.%(ext)s')
                task.update_progress(title='B站下载')
            elif 'music.163.com' in url:
                ydl_opts['outtmpl'] = os.path.join(download_path, 'NeteaseCloudMusic', '%(title)s.%(ext)s')
                task.update_progress(title='网易云音乐下载')
            else:
                ydl_opts['outtmpl'] = os.path.join(download_path, 'Downloads', '%(title)s.%(ext)s')
                task.update_progress(title='下载中')
            
            # 确保目录存在
            os.makedirs(os.path.dirname(ydl_opts['outtmpl']), exist_ok=True)
            
            # 执行下载
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                
                # 获取文件信息
                filename = ydl.prepare_filename(info)
                title = info.get('title', '未知')
                
                # 检查文件是否存在
                if os.path.exists(filename):
                    filesize = os.path.getsize(filename)
                else:
                    # 可能转换后扩展名改变
                    base_name = os.path.splitext(filename)[0]
                    for ext in ['.mp3', '.mp4', '.mkv', '.webm']:
                        test_file = base_name + ext
                        if os.path.exists(test_file):
                            filename = test_file
                            filesize = os.path.getsize(filename)
                            break
                    else:
                        filesize = 0
                
                # 更新任务状态为完成
                task.update_progress(
                    status='finished',
                    percent=100.0,
                    title=title,
                    filename=os.path.basename(filename),
                    filesize=filesize,
                    path=os.path.dirname(filename),
                    quality=quality
                )
                
                logger.info(f"✅ 下载完成: {filename}")
                
        except Exception as e:
            logger.error(f"❌ 下载失败: {e}", exc_info=True)
            task.update_progress(
                status='error',
                error=str(e),
                title='下载失败'
            )
    
    return bp


if __name__ == "__main__":
    # 用于测试
    from flask import Flask
    app = Flask(__name__)
    bp = create_downloader_blueprint()
    app.register_blueprint(bp)
    app.run(host='0.0.0.0', port=8530, debug=True)
