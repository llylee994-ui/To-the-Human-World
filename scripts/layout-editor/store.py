"""Local, transactional project storage. No third-party runtime dependencies."""
import copy
import hashlib
import io
import json
import math
import re
import sqlite3
import struct
import threading
import time
import uuid
import zipfile
from pathlib import Path

VERSION = "0.1.0"
FORMAT = "to-human-world-layout"
LEASE_SECONDS = 18
MAX_IMAGE = 30 * 1024 * 1024
MAX_ARCHIVE = 300 * 1024 * 1024
MAX_ASSET_BYTES = 250 * 1024 * 1024


class Problem(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def uid():
    return str(uuid.uuid4())


def require(condition, message, status=400):
    if not condition:
        raise Problem(message, status)


def identifier(value):
    require(isinstance(value, str) and bool(re.fullmatch(r"[A-Za-z0-9_-]{1,80}", value)), "标识无效")
    return value


def title(value):
    require(isinstance(value, str) and 0 < len(value.strip()) <= 80, "名称应为 1–80 个字符")
    return value.strip()


def number(value, low, high):
    require(type(value) in (int, float) and math.isfinite(value) and low <= value <= high, "画布数值无效")
    return value


def image_info(raw):
    require(0 < len(raw) <= MAX_IMAGE, "单张图片最大 30 MB")
    if raw.startswith(b"\x89PNG\r\n\x1a\n") and len(raw) >= 33:
        require(raw[12:16] == b"IHDR" and b"IEND" in raw[-16:], "PNG 文件不完整")
        width, height = struct.unpack(">II", raw[16:24])
        mime, ext = "image/png", "png"
    elif raw.startswith(b"\xff\xd8"):
        stream = io.BytesIO(raw[2:])
        width = height = 0
        while stream.tell() < len(raw) - 2:
            marker = stream.read(1)
            if marker != b"\xff":
                continue
            code = stream.read(1)
            while code == b"\xff":
                code = stream.read(1)
            if not code or code[0] in (0xD9, 0xDA):
                break
            if code[0] in (0x00, 0xD8) or 0xD0 <= code[0] <= 0xD7:
                continue
            size_bytes = stream.read(2)
            require(len(size_bytes) == 2, "JPEG 文件不完整")
            size = struct.unpack(">H", size_bytes)[0]
            require(size >= 2, "JPEG 格式无效")
            if code[0] in (0xC0, 0xC1, 0xC2):
                data = stream.read(5)
                require(len(data) == 5, "JPEG 文件不完整")
                height, width = struct.unpack(">HH", data[1:])
                break
            stream.seek(size - 2, 1)
        mime, ext = "image/jpeg", "jpg"
    elif raw.startswith(b"RIFF") and raw[8:12] == b"WEBP":
        width = height = 0
        offset = 12
        while offset + 8 <= len(raw):
            kind, size = raw[offset:offset + 4], int.from_bytes(raw[offset + 4:offset + 8], "little")
            data = raw[offset + 8:offset + 8 + size]
            if kind == b"VP8X" and len(data) >= 10:
                width = int.from_bytes(data[4:7], "little") + 1
                height = int.from_bytes(data[7:10], "little") + 1
                break
            if kind == b"VP8 " and len(data) >= 10 and data[3:6] == b"\x9d\x01\x2a":
                width, height = struct.unpack("<HH", data[6:10])
                width, height = width & 0x3FFF, height & 0x3FFF
                break
            if kind == b"VP8L" and len(data) >= 5 and data[0] == 0x2F:
                bits = int.from_bytes(data[1:5], "little")
                width, height = (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
                break
            offset += 8 + size + size % 2
        mime, ext = "image/webp", "webp"
    else:
        raise Problem("请选择 PNG、WebP 或 JPEG 图片；透明素材推荐 PNG")
    require(0 < width <= 16384 and 0 < height <= 16384 and width * height <= 80_000_000, "图片尺寸无效或超过 8000 万像素")
    return {"width": width, "height": height, "mime": mime, "ext": ext}


def validate_page(page, assets):
    require(isinstance(page, dict), "页面格式无效")
    identifier(page.get("id"))
    page["name"] = title(page.get("name"))
    number(page.get("width"), 100, 8192)
    number(page.get("height"), 100, 8192)
    require(isinstance(page.get("background"), str) and bool(re.fullmatch(r"#[0-9a-fA-F]{6}", page["background"])), "背景颜色无效")
    layers = page.get("layers")
    require(isinstance(layers, list) and len(layers) <= 1000, "每页最多 1000 个图层")
    ids, groups = set(), set()
    for layer in layers:
        require(isinstance(layer, dict), "图层格式无效")
        key = identifier(layer.get("id"))
        require(key not in ids, "图层 ID 重复")
        ids.add(key)
        require(layer.get("assetId") in assets, "图层引用了缺失的素材")
        layer["name"] = title(layer.get("name"))
        for key in ("x", "y"):
            number(layer.get(key), -100000, 100000)
        number(layer.get("width"), 1, 32768)
        number(layer.get("height"), 1, 32768)
        number(layer.get("rotation"), -360000, 360000)
        require(type(layer.get("visible")) is bool and type(layer.get("locked")) is bool, "图层状态无效")
        if layer.get("groupId"):
            groups.add(identifier(layer["groupId"]))
    # A group is one contiguous z-order block, transformed as a rigid selection.
    for group in groups:
        positions = [i for i, layer in enumerate(layers) if layer.get("groupId") == group]
        require(len(positions) >= 2 and positions[-1] - positions[0] + 1 == len(positions), "组内图层必须连续且至少有两个成员")
    return page


class Store:
    def __init__(self, directory):
        self.directory = Path(directory).resolve()
        self.directory.mkdir(parents=True, exist_ok=True)
        self.mutex = threading.RLock()
        self.leases = {}
        self.db = sqlite3.connect(self.directory / "project.sqlite3", check_same_thread=False)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.execute("CREATE TABLE IF NOT EXISTS project (id INTEGER PRIMARY KEY, document TEXT NOT NULL)")
        self.db.execute("CREATE TABLE IF NOT EXISTS assets (id TEXT PRIMARY KEY, metadata TEXT NOT NULL, data BLOB NOT NULL)")
        if not self.db.execute("SELECT 1 FROM project WHERE id=1").fetchone():
            self.write({"format": FORMAT, "schemaVersion": 1, "appVersion": VERSION, "id": uid(), "epoch": uid(),
                        "name": "寄往人间 · 页面排版", "revision": 0,
                        "pages": [{"id": uid(), "name": "主页", "width": 1080, "height": 1920,
                                   "background": "#f5f0e7", "revision": 0, "layers": []}]})
            self.db.commit()

    def read(self):
        return json.loads(self.db.execute("SELECT document FROM project WHERE id=1").fetchone()[0])

    def write(self, document):
        encoded = json.dumps(document, ensure_ascii=False, indent=2)
        require(len(encoded.encode('utf-8')) <= 12 * 1024 * 1024, "布局总大小达到 12 MB 上限，请导出备份后拆分项目")
        self.db.execute("INSERT OR REPLACE INTO project VALUES (1, ?)", (encoded,))

    def assets(self):
        return [json.loads(row[0]) for row in self.db.execute("SELECT metadata FROM assets ORDER BY rowid")]

    def expire(self):
        now = time.monotonic()
        self.leases = {key: value for key, value in self.leases.items() if value["until"] > now}

    def state(self):
        with self.mutex:
            self.expire()
            doc = self.read()
            doc["assets"] = self.assets()
            doc["leases"] = {key: {"owner": value["owner"], "token": value["token"]} for key, value in self.leases.items()}
            return doc

    def context(self, request):
        doc = self.read()
        require(request.get("epoch") == doc["epoch"], "项目已被导入替换，请载入最新项目", 409)
        return doc

    def page(self, doc, page_id):
        found = next((p for p in doc["pages"] if p["id"] == page_id), None)
        require(found is not None, "页面已不存在", 404)
        return found

    def lease(self, request, release=False):
        with self.mutex:
            doc = self.context(request)
            page_id = request.get("pageId")
            self.page(doc, page_id)
            owner = identifier(request.get("clientId"))
            self.expire()
            current = self.leases.get(page_id)
            if release:
                if current and current["owner"] == owner and current["token"] == request.get("token"):
                    del self.leases[page_id]
                return {"released": True}
            if request.get("token"):
                require(current and current["owner"] == owner and current["token"] == request["token"], "编辑会话已到期，请重新取得编辑权", 423)
            require(not current or current["owner"] == owner, "此页正在另一窗口编辑，本窗口实时查看", 423)
            if not current:
                current = {"owner": owner, "token": uid()}
            current["until"] = time.monotonic() + LEASE_SECONDS
            self.leases[page_id] = current
            return {"token": current["token"], "page": copy.deepcopy(self.page(doc, page_id))}

    def save_page(self, request):
        with self.mutex, self.db:
            doc = self.context(request)
            page = self.page(doc, request.get("pageId"))
            self.expire()
            lease = self.leases.get(page["id"])
            require(lease and lease["owner"] == request.get("clientId") and lease["token"] == request.get("token"), "编辑权已失效，未覆盖其他窗口的内容。请重新取得编辑权。", 423)
            require(request.get("revision") == page["revision"], "页面已有更新，本次旧版本未保存", 409)
            incoming = copy.deepcopy(request.get("page"))
            validate_page(incoming, {item["id"] for item in self.assets()})
            require(incoming["id"] == page["id"], "页面标识不能改变")
            incoming["revision"] = page["revision"] + 1
            doc["pages"][doc["pages"].index(page)] = incoming
            doc["revision"] += 1
            self.write(doc)
            return {"page": incoming, "revision": doc["revision"]}

    def create_page(self, request):
        with self.mutex, self.db:
            doc = self.context(request)
            require(len(doc["pages"]) < 100, "最多支持 100 个页面")
            page = {"id": uid(), "name": title(request.get("name")), "width": 1080, "height": 1920,
                    "background": "#f5f0e7", "revision": 0, "layers": []}
            doc["pages"].append(page)
            doc["revision"] += 1
            self.write(doc)
            return page

    def upload(self, request, raw, name):
        info = image_info(raw)
        name = title(name)
        digest = hashlib.sha256(raw).hexdigest()
        with self.mutex, self.db:
            doc = self.context(request)
            for existing in self.assets():
                if existing["sha256"] == digest:
                    return existing
            count, size = self.db.execute("SELECT count(*),coalesce(sum(length(data)),0) FROM assets").fetchone()
            require(count < 3000 and size + len(raw) <= MAX_ASSET_BYTES, "素材库达到 250 MB 或 3000 张上限，请导出备份并另存项目")
            asset = {"id": uid(), "name": name, "sha256": digest, **info}
            self.db.execute("INSERT INTO assets VALUES (?,?,?)", (asset["id"], json.dumps(asset, ensure_ascii=False), raw))
            doc["revision"] += 1
            self.write(doc)
            return asset

    def asset(self, asset_id):
        with self.mutex:
            row = self.db.execute("SELECT metadata,data FROM assets WHERE id=?", (asset_id,)).fetchone()
            require(row is not None, "素材不存在", 404)
            return json.loads(row[0]), row[1]

    def export(self):
        with self.mutex:
            doc = self.read()
            doc["coordinateSystem"] = {"origin": "top-left", "position": "center", "unit": "design-pixel", "rotation": "clockwise-degrees", "layerOrder": "bottom-to-top", "groups": "contiguous rigid blocks; member transforms in page coordinates"}
            doc["assets"] = self.assets()
            output = io.BytesIO()
            with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
                for item in doc["assets"]:
                    item["file"] = f"assets/{item['id']}.{item['ext']}"
                    archive.writestr(item["file"], self.asset(item["id"])[1])
                archive.writestr("project.json", json.dumps(doc, ensure_ascii=False, indent=2))
            return output.getvalue()

    def import_project(self, request, raw):
        require(len(raw) <= MAX_ARCHIVE, "项目包最大 300 MB")
        try:
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                entries = archive.infolist()
                require(len(entries) <= 3001 and sum(item.file_size for item in entries) <= MAX_ARCHIVE, "项目包解压后过大")
                require(len({item.filename for item in entries}) == len(entries), "项目包存在重复路径")
                require(archive.getinfo("project.json").file_size <= 15 * 1024 * 1024, "布局文件过大")
                doc = json.loads(archive.read("project.json"))
                require(isinstance(doc, dict) and doc.get("format") == FORMAT and doc.get("schemaVersion") == 1, "不支持此项目格式或版本")
                doc["name"] = title(doc.get("name"))
                identifier(doc.get("id"))
                assets = doc.pop("assets", None)
                require(isinstance(assets, list) and len(assets) <= 3000, "素材列表无效")
                imported = {}
                for item in assets:
                    key = identifier(item.get("id"))
                    require(key not in imported, "素材 ID 重复")
                    title(item.get("name"))
                    require(item.get("ext") in ("png", "jpg", "webp"), "素材扩展名无效")
                    require(item.get("file") == f"assets/{key}.{item['ext']}", "素材路径无效")
                    data = archive.read(item["file"])
                    actual = image_info(data)
                    require(all(item.get(k) == v for k, v in actual.items()) and item.get("sha256") == hashlib.sha256(data).hexdigest(), "素材完整性或尺寸校验失败")
                    item.pop("file", None)
                    imported[key] = (item, data)
                pages = doc.get("pages")
                require(isinstance(pages, list) and 0 < len(pages) <= 100, "页面列表无效")
                require(len({p["id"] for p in pages}) == len(pages), "页面 ID 重复")
                for page in pages:
                    validate_page(page, imported)
                    page["revision"] = 0
                require(sum(len(data) for _, data in imported.values()) <= MAX_ASSET_BYTES, "素材总大小超过 250 MB")
        except Problem:
            raise
        except (zipfile.BadZipFile, KeyError, TypeError, ValueError, RuntimeError, OSError) as error:
            raise Problem("无法读取项目包，原项目保持不变") from error
        with self.mutex, self.db:
            current = self.context(request)
            require(request.get("revision") == current["revision"], "项目已有新修改，请刷新后重新导入", 409)
            self.expire()
            require(all(item["owner"] == request.get("clientId") for item in self.leases.values()), "其他窗口正在编辑，请先让其释放编辑权再导入", 423)
            backups = self.directory / "backups"
            backups.mkdir(exist_ok=True)
            backup = backups / f"before-import-{time.strftime('%Y%m%d-%H%M%S')}-{uid()[:8]}.zip"
            backup.write_bytes(self.export())
            doc["epoch"] = uid()
            doc["revision"] = 0
            doc["appVersion"] = VERSION
            self.db.execute("DELETE FROM assets")
            for key, (item, data) in imported.items():
                self.db.execute("INSERT INTO assets VALUES (?,?,?)", (key, json.dumps(item, ensure_ascii=False), data))
            self.write(doc)
            self.leases.clear()
            return {"backup": backup.name}
