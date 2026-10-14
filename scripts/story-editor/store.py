"""Shared story JSON; graph validation, optimistic revisions and atomic saves."""
import hashlib
import json
import math
import os
import re
import tempfile
import threading
import time
import uuid
from pathlib import Path

KINDS = {'root', 'act', 'ordinary', 'main', 'choice', 'candidate', 'result', 'followup', 'merge', 'ending', 'note'}
TEXT_FIELDS = ('title', 'summary', 'conditions', 'effects', 'notes', 'status', 'context', 'options', 'unselected', 'wishAId', 'wishBId', 'templateId')


class Problem(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def require(condition, message, status=400):
    if not condition:
        raise Problem(message, status)


def validate(project):
    require(isinstance(project, dict), '项目必须是JSON对象')
    require(project.get('format') == 'human-world-story' and project.get('version') == 1, '不是支持的剧情图格式')
    require(isinstance(project.get('title'), str) and 0 < len(project['title']) <= 300, '项目名称无效')
    nodes, edges = project.get('nodes'), project.get('edges')
    require(isinstance(nodes, list) and 0 < len(nodes) <= 2500, '需要1～2500个节点')
    require(isinstance(edges, list) and len(edges) <= 6000, '连接数量无效')
    by_id = {}
    templates = project.get('templates', [])
    require(isinstance(templates, list) and len(templates) <= 200, '模板库格式无效')
    template_ids = set()
    for template in templates:
        require(isinstance(template, dict) and isinstance(template.get('id'), str) and re.fullmatch(r'[A-Za-z0-9_-]{1,100}', template['id']) and template['id'] not in template_ids, '模板ID无效或重复')
        for key in ('id', 'title', 'summary'):
            require(isinstance(template.get(key), str) and 0 < len(template[key]) <= (60000 if key == 'summary' else 300), '模板内容无效')
        template_ids.add(template['id'])
    for node in nodes:
        require(isinstance(node, dict), '节点无效')
        nid = node.get('id')
        require(isinstance(nid, str) and re.fullmatch(r'[A-Za-z0-9_-]{1,100}', nid), '节点ID无效')
        require(nid not in by_id, '节点ID重复')
        require(node.get('kind') in KINDS, '节点类型无效')
        require(isinstance(node.get('title'), str) and 0 < len(node['title']) <= 300, '节点标题不能为空或超过300字')
        for key in TEXT_FIELDS:
            require(key not in node or isinstance(node[key], str) and len(node[key]) <= 60000, '节点文字过长或格式错误')
        for key in ('dx', 'dy'):
            value = node.get(key, 0)
            require(type(value) in (int, float) and math.isfinite(value) and abs(value) <= 100000, '节点位置无效')
        day = node.get('day')
        require(day is None or type(day) is int and 1 <= day <= 9999, '日程须为正整数或留空')
        if day is not None and node['kind'] in ('ordinary', 'main', 'choice'):
            require(day % 2 == (1 if node['kind'] == 'ordinary' else 0), '普通愿望放奇数日，主线放偶数日')
        by_id[nid] = node
        if project.get('layout') == 'route':
            require(type(node.get('round')) is int and 0 <= node['round'] <= 999, '主线轮次须为0～999的整数')
            require(type(node.get('step')) is int and 0 <= node['step'] <= 99, '轮内步骤须为0～99的整数')
        require(not node.get('templateId') or node['templateId'] in template_ids, '场景模板不存在')
    roots = [n for n in nodes if n.get('parentId') is None]
    require(len(roots) == 1 and roots[0]['kind'] == 'root', '须保留一个故事根节点')
    for node in nodes:
        seen, current = set(), node
        while current.get('parentId') is not None:
            require(current['id'] not in seen, '父级关系不能成环')
            seen.add(current['id'])
            require(current['parentId'] in by_id, '父级节点不存在')
            current = by_id[current['parentId']]
    edge_ids = set()
    for edge in edges:
        require(isinstance(edge, dict) and isinstance(edge.get('id'), str), '连接无效')
        require(edge['id'] not in edge_ids, '连接ID重复')
        edge_ids.add(edge['id'])
        require(edge.get('from') in by_id and edge.get('to') in by_id, '连接端点不存在')
        require(edge['from'] != edge['to'], '不能连接到自身')
        if project.get('layout') == 'route':
            source, target = by_id[edge['from']], by_id[edge['to']]
            require((source['round'], source['step']) < (target['round'], target['step']), '后续必须向后推进；请调整轮次或轮内步骤')
        for key in ('label', 'condition', 'kind'):
            require(key not in edge or isinstance(edge[key], str) and len(edge[key]) <= 2000, '连接文字无效')
        require('wish' not in edge or edge['wish'] in ('A', 'B'), '出口选瓶只能是A或B')


class Store:
    def __init__(self, path):
        self.path = Path(path).resolve()
        self.lock = threading.RLock()

    def read(self):
        with self.lock:
            try:
                raw = self.path.read_bytes()
                require(len(raw) <= 12 * 1024 * 1024, '项目超过12MB')
                project = json.loads(raw)
                validate(project)
            except (OSError, ValueError) as error:
                raise Problem('无法读取剧情图，请检查文件；未覆盖原文件', 422) from error
            return {'project': project, 'revision': hashlib.sha256(raw).hexdigest()}

    def save(self, project, revision):
        with self.lock:
            validate(project)
            state = self.read()
            require(revision == state['revision'], '其他窗口或Codex已修改，请下载当前草稿后载入最新版本', 409)
            data = (json.dumps(project, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
            require(len(data) <= 12 * 1024 * 1024, '项目超过12MB', 413)
            if data == self.path.read_bytes():
                return state
            old = self.path.read_bytes()
            require(hashlib.sha256(old).hexdigest() == revision, '文件刚被修改，请载入最新版本', 409)
            backup_dir = self.path.parent / '.story-backups'
            backup_dir.mkdir(exist_ok=True)
            backup = backup_dir / f'{time.time_ns()}-{uuid.uuid4().hex[:6]}.json'
            backup.write_bytes(old)
            fd, name = tempfile.mkstemp(prefix='.story-', suffix='.tmp', dir=self.path.parent)
            try:
                with os.fdopen(fd, 'wb') as file:
                    file.write(data)
                    file.flush()
                    os.fsync(file.fileno())
                require(hashlib.sha256(self.path.read_bytes()).hexdigest() == revision, '文件刚被修改，请载入最新版本', 409)
                os.replace(name, self.path)
            finally:
                if os.path.exists(name):
                    os.unlink(name)
            return self.read()
