"""Local story editor. python -B server.py [--no-browser] [--port 18766]."""
import argparse
import json
import mimetypes
import os
import secrets
import threading
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from store import Store, Problem, require

ROOT = Path(__file__).resolve().parent
DEFAULT_PROJECT = ROOT.parents[1] / 'docs' / '文案' / '主线' / '主线故事图_v01.json'


def handler_class(store, token):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def trusted(self):
            hosts = {f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'}
            require(self.headers.get('Host') in hosts, '仅允许本机访问', 403)
            require(not self.headers.get('Origin') or self.headers['Origin'] in {'http://' + h for h in hosts}, '请求来源不匹配', 403)

        def reply(self, data, status=200, mime='application/json; charset=utf-8'):
            if isinstance(data, dict):
                data = json.dumps(data, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; object-src 'none'; base-uri 'none'")
            self.end_headers()
            try:
                self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                pass

        def do_GET(self):
            try:
                self.trusted()
                path = urllib.parse.urlsplit(self.path).path
                if path == '/api/health':
                    return self.reply({'app': 'human-world-story', 'projectPath': str(store.path)})
                if path == '/api/project':
                    return self.reply({**store.read(), 'token': token})
                files = {'/': 'index.html', '/index.html': 'index.html', '/style.css': 'style.css', '/app.js': 'app.js', '/map.js': 'map.js', '/routes.js': 'routes.js'}
                require(path in files, '页面不存在', 404)
                file = ROOT / 'web' / files[path]
                mime = 'text/javascript' if file.suffix == '.js' else mimetypes.guess_type(file.name)[0]
                self.reply(file.read_bytes(), mime=(mime or 'text/plain') + '; charset=utf-8')
            except Problem as error:
                self.reply({'error': str(error)}, error.status)
            except OSError:
                self.reply({'error': '页面文件未找到'}, 404)

        def do_POST(self):
            try:
                self.trusted()
                require(self.path == '/api/project', '接口不存在', 404)
                require(secrets.compare_digest(self.headers.get('X-Editor-Token', ''), token), '请刷新编辑器后重试', 403)
                length = int(self.headers.get('Content-Length', '0'))
                require(0 < length <= 12 * 1024 * 1024, '请求过大或为空', 413)
                body = json.loads(self.rfile.read(length))
                require(isinstance(body, dict), '请求格式错误')
                self.reply(store.save(body.get('project'), body.get('revision')))
            except Problem as error:
                self.reply({'error': str(error)}, error.status)
            except (ValueError, TypeError, KeyError):
                self.reply({'error': '请求格式错误，未保存'}, 400)
            except Exception as error:
                print(f'{type(error).__name__}: {error}', flush=True)
                self.reply({'error': '保存失败，请保留当前窗口或下载草稿'}, 500)
    return Handler


def lock_project(path):
    file = open(path.parent / '.story-editor.lock', 'a+b')
    try:
        if os.fstat(file.fileno()).st_size == 0:
            file.write(b'1'); file.flush()
        file.seek(0)
        if os.name == 'nt':
            import msvcrt
            msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        file.close()
        raise SystemExit('该剧情图已由另一个服务打开，请复用现有地址。')
    return file


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=18766)
    parser.add_argument('--project', type=Path, default=DEFAULT_PROJECT)
    parser.add_argument('--no-browser', action='store_true')
    args = parser.parse_args()
    path = args.project.resolve()
    url = f'http://127.0.0.1:{args.port}'
    if args.port:
        try:
            with urllib.request.urlopen(url + '/api/health', timeout=1) as response:
                health = json.load(response)
            if health.get('app') == 'human-world-story' and health.get('projectPath') == str(path):
                print(url, flush=True)
                if not args.no_browser:
                    webbrowser.open(url)
                return
        except (OSError, ValueError):
            pass
    store = Store(path)
    store.read()
    lock = lock_project(path)
    try:
        server = ThreadingHTTPServer(('127.0.0.1', args.port), handler_class(store, secrets.token_urlsafe(32)))
    except OSError:
        lock.close()
        raise SystemExit('端口被占用；请指定--port或复用原服务。')
    server.daemon_threads = True
    url = f'http://127.0.0.1:{server.server_port}'
    print(f'Story editor: {url}\nProject: {path}', flush=True)
    if not args.no_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        lock.close()


if __name__ == '__main__':
    main()
