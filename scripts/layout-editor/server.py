"""Run: python server.py [--no-browser] [--port 18765] [--data-dir PATH]."""
import argparse
import hashlib
import json
import mimetypes
import os
import secrets
import threading
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from store import MAX_ARCHIVE, MAX_IMAGE, VERSION, Problem, Store, require

ROOT = Path(__file__).resolve().parent


def lock_directory(directory):
    directory.mkdir(parents=True, exist_ok=True)
    # Maker copies scripts into its managed preview. A Windows byte-locked file
    # inside scripts makes that copy fail with EBUSY while this editor is open.
    lock_root = Path(tempfile.gettempdir()) / 'to-human-world-layout-locks'
    lock_root.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256(os.path.normcase(str(directory.resolve())).encode('utf-8')).hexdigest()
    lock = open(lock_root / (key + '.lock'), 'a+b')
    try:
        if os.fstat(lock.fileno()).st_size == 0:
            lock.write(b'1'); lock.flush()
        lock.seek(0)
        if os.name == 'nt':
            import msvcrt
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        lock.close()
        raise SystemExit('This project is already open in another editor server. Reuse its browser URL.')
    return lock


def handler_class(store, secret):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            if args and str(args[1] if len(args) > 1 else "").startswith("5"):
                super().log_message(format, *args)

        def reply(self, body, status=200, content_type="application/json; charset=utf-8", headers=None):
            if isinstance(body, dict) or isinstance(body, list):
                body = json.dumps(body, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'none'")
            for key, value in (headers or {}).items():
                self.send_header(key, value)
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                pass

        def trusted(self):
            expected = {f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"}
            require(self.headers.get("Host") in expected, "仅允许本机访问", 403)
            origin = self.headers.get("Origin")
            require(not origin or origin in {"http://" + host for host in expected}, "请求来源不匹配", 403)

        def do_GET(self):
            try:
                self.trusted()
                path = urllib.parse.urlsplit(self.path).path
                if path == "/api/health":
                    return self.reply({"app": "human-world-layout", "version": VERSION, "storageKey": hashlib.sha256(str(store.directory).encode()).hexdigest()})
                if path == "/api/state":
                    return self.reply({**store.state(), "csrf": secret})
                if path == "/api/export":
                    return self.reply(store.export(), content_type="application/zip", headers={"Content-Disposition": 'attachment; filename="human-world-layout-v0.1.zip"'})
                if path.startswith("/api/asset/"):
                    info, data = store.asset(path.removeprefix("/api/asset/"))
                    return self.reply(data, content_type=info["mime"])
                files = {"/": "index.html", "/index.html": "index.html", "/style.css": "style.css", "/app.js": "app.js", "/canvas.js": "canvas.js"}
                require(path in files, "页面不存在", 404)
                file = ROOT / "web" / files[path]
                mime = "text/javascript" if file.suffix == ".js" else mimetypes.guess_type(file.name)[0]
                self.reply(file.read_bytes(), content_type=(mime or "text/plain") + "; charset=utf-8")
            except Problem as error:
                self.reply({"error": str(error)}, error.status)

        def do_POST(self):
            try:
                self.trusted()
                require(secrets.compare_digest(self.headers.get("X-Editor-Token", ""), secret), "请刷新编辑器后重试", 403)
                parsed = urllib.parse.urlsplit(self.path)
                query = {key: values[0] for key, values in urllib.parse.parse_qs(parsed.query).items()}
                length = int(self.headers.get("Content-Length", "0"))
                limit = MAX_ARCHIVE if parsed.path == "/api/import" else MAX_IMAGE if parsed.path == "/api/assets" else 15 * 1024 * 1024
                require(0 < length <= limit, "请求内容过大或为空", 413)
                raw = self.rfile.read(length)
                require(len(raw) == length, "请求未传输完整")
                if parsed.path == "/api/assets":
                    result = store.upload(query, raw, query.get("name", "素材"))
                elif parsed.path == "/api/import":
                    query["revision"] = int(query.get("revision", "-1"))
                    result = store.import_project(query, raw)
                else:
                    request = json.loads(raw)
                    require(isinstance(request, dict), "请求格式无效")
                    routes = {"/api/pages": store.create_page, "/api/save": store.save_page,
                              "/api/lease": store.lease, "/api/release": lambda r: store.lease(r, release=True)}
                    require(parsed.path in routes, "接口不存在", 404)
                    result = routes[parsed.path](request)
                self.reply(result)
            except Problem as error:
                self.reply({"error": str(error)}, error.status)
            except (ValueError, TypeError, KeyError):
                self.reply({"error": "请求格式无效，未保存"}, 400)
            except Exception as error:
                print(f"[editor] {type(error).__name__}: {error}", flush=True)
                self.reply({"error": "保存服务发生错误，当前修改尚未确认保存；请保留窗口并检查启动日志"}, 500)
    return Handler


def main(argv=None, initialize=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=18765)
    parser.add_argument("--data-dir", type=Path, default=ROOT / ".local")
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args(argv)
    url = f"http://127.0.0.1:{args.port}"
    storage_key = hashlib.sha256(str(args.data_dir.resolve()).encode()).hexdigest()
    if args.port:
        try:
            with urllib.request.urlopen(url + "/api/health", timeout=1) as response:
                running = json.load(response)
            if running.get("app") == "human-world-layout" and running.get("storageKey") == storage_key:
                print("Editor already running: " + url, flush=True)
                if not args.no_browser:
                    webbrowser.open(url)
                return
        except (OSError, ValueError):
            pass
    directory_lock = lock_directory(args.data_dir.resolve())
    store = Store(args.data_dir)
    if initialize:
        initialize(store)
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), handler_class(store, secrets.token_urlsafe(32)))
    except OSError:
        raise SystemExit(f"Port {args.port} is in use. Close the other service or specify --port. No data was replaced.")
    server.daemon_threads = True
    url = f"http://127.0.0.1:{server.server_port}"
    print(f"Layout editor v{VERSION}: {url}\nData: {store.directory}\nKeep this window open. Ctrl+C stops the server.", flush=True)
    if not args.no_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        store.db.close()
        directory_lock.close()


if __name__ == "__main__":
    main()
