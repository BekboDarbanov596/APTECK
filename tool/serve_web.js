// Простой статический сервер для собранной веб-версии (build/web).
// Запуск: flutter build web && node tool/serve_web.js  → http://localhost:8091
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'build', 'web');
const previewPrefix = '/__preview/';
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.otf': 'font/otf', '.ttf': 'font/ttf', '.css': 'text/css', '.ico': 'image/x-icon',
  '.frag': 'application/octet-stream', '.bin': 'application/octet-stream',
};

http.createServer((req, res) => {
  let urlPath;
  try {
    urlPath = decodeURIComponent(req.url.split('?')[0]);
  } catch {
    res.writeHead(400).end();
    return;
  }

  // Preview files bypass both HTTP caching and the deployed Flutter worker.
  res.setHeader('Cache-Control', 'no-store');
  if (urlPath === '/phone.html') {
    res.setHeader('Content-Type', types['.html']);
    fs.createReadStream(path.join(__dirname, '..', 'web', 'phone.html')).pipe(res);
    return;
  }

  const preview = urlPath.startsWith(previewPrefix);
  const resource = preview ? urlPath.slice(previewPrefix.length) : urlPath;
  let file = path.join(root, resource);
  if (file !== root && !file.startsWith(root + path.sep)) {
    res.writeHead(403).end();
    return;
  }
  if (!path.extname(resource)) file = path.join(root, 'index.html');

  if (preview && (resource === '' || resource === 'index.html' || resource === 'flutter_bootstrap.js')) {
    fs.readFile(file, 'utf8', (error, source) => {
      if (error) {
        res.writeHead(503, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('Веб-сборка ещё не готова. Обновите страницу после flutter build web.');
        return;
      }
      const bootstrap = resource === 'flutter_bootstrap.js';
      if (bootstrap) {
        const loaderStart = source.lastIndexOf('_flutter.loader.load(');
        if (loaderStart === -1) {
          res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
          res.end('Не удалось настроить загрузчик Flutter для превью.');
          return;
        }
        source = source.slice(0, loaderStart) +
          '_flutter.loader.load({config:{canvasKitBaseUrl:"/__preview/canvaskit/"}});';
      } else {
        source = source.replace(/<base href="[^"]*">/, '<base href="' + previewPrefix + '">');
      }
      res.setHeader('Content-Type', types[bootstrap ? '.js' : '.html']);
      res.end(source);
    });
    return;
  }

  const stream = fs.createReadStream(file);
  stream.once('open', () => {
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    stream.pipe(res);
  });
  stream.on('error', () => {
    if (res.headersSent) return res.destroy();
    res.writeHead(404).end();
  });
}).listen(8091, () => console.log('http://localhost:8091'));
