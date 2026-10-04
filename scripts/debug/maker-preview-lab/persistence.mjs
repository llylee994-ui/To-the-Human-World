// Local experiment only: opt-in, one real project, no savedata copy/restore.
import fs from 'node:fs';
import path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';

const allowedProject = 'D:/taptap/To-the-Human-World';
const storeRoot = 'D:/taptap/.mpv/data';

function directory(directoryPath) {
  const resolved = path.resolve(directoryPath);
  const parent = path.dirname(resolved);
  if (parent !== resolved) directory(parent);
  if (!fs.existsSync(resolved)) fs.mkdirSync(resolved, { mode: 0o700 });
  const stat = fs.lstatSync(resolved);
  if (stat.isSymbolicLink() || !stat.isDirectory() || fs.realpathSync(resolved).toLowerCase() !== resolved.toLowerCase())
    throw new Error('Persistent preview directory is not an owned regular directory.');
  return resolved;
}

export function openPersistentPreview(project, networkRequired, root = storeRoot) {
  if (process.env.MAKER_PREVIEW_PERSISTENCE_LAB !== '1') return undefined;
  if (process.platform !== 'win32' || networkRequired || fs.realpathSync(project).toLowerCase() !== fs.realpathSync(allowedProject).toLowerCase())
    throw new Error('Persistence experiment is restricted to the authorized Windows single-player project.');
  const canonical = fs.realpathSync(project);
  const key = createHash('sha256').update(canonical.toLowerCase()).digest('hex').slice(0, 16);
  const dir = directory(path.join(root, key));
  const identityFile = path.join(dir, 'identity.json');
  const readIdentity = () => {
    if (fs.lstatSync(identityFile).isSymbolicLink()) throw new Error('Persistent preview identity was replaced.');
    const value = JSON.parse(fs.readFileSync(identityFile, 'utf8'));
    if (value.version !== 1 || value.project !== canonical || !/^[a-f0-9]{64}$/.test(value.token) ||
        !Number.isInteger(value.port) || value.port < 0 || value.port > 65535)
      throw new Error('Invalid persistent preview identity; retain files for diagnosis.');
    return value;
  };
  if (!fs.existsSync(identityFile)) {
    fs.writeFileSync(identityFile, JSON.stringify({version:1,project:canonical,token:randomBytes(32).toString('hex'),port:0}), {flag:'wx',mode:0o600});
  }
  const identity = readIdentity();
  const cacheRoot = directory(path.join(dir, 'cache'));
  return {
    cacheRoot, token:identity.token, port:identity.port,
    commitPort(port) {
      const current = readIdentity();
      if (current.token !== identity.token || current.port !== identity.port || !Number.isInteger(port) || port < 1 || port > 65535)
        throw new Error('Persistent preview identity changed during startup.');
      if (identity.port && identity.port !== port) throw new Error('Persistent preview port must not change.');
      if (!identity.port) {
        // Initial allocation only, before Runtime starts. A partial file fails closed next time.
        fs.writeFileSync(identityFile, JSON.stringify({...identity,port}), {mode:0o600});
        identity.port = port;
      }
    },
    retain() {
      const current = readIdentity();
      if (current.token !== identity.token || current.port !== identity.port || directory(cacheRoot) !== cacheRoot)
        throw new Error('Persistent preview ownership changed; do not delete any files.');
    }
  };
}
