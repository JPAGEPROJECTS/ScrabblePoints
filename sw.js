// Service worker: permite instalar la app y abrirla sin conexión.
// App: "red primero" (siempre intenta la versión más nueva y usa la caché si no hay internet).
// Diccionario (dict/): "caché primero" en una caché aparte; las listas no cambian, así que cada
// trozo se descarga una sola vez. Si se cambian las listas, sube DICT_CACHE a la siguiente versión.
var CACHE = 'marcador-scrabble-v2';
var DICT_CACHE = 'marcador-dict-v1';
var ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png',
  './icons/apple-touch-icon.png'
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE).then(function (cache) { return cache.addAll(ASSETS); }).then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (k) { return k !== CACHE && k !== DICT_CACHE; }).map(function (k) { return caches.delete(k); }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (event) {
  var req = event.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  // Solo archivos propios; Supabase, fuentes y CDN van directos a la red.
  if (url.origin !== self.location.origin) return;

  if (url.pathname.indexOf('/dict/') !== -1) {
    event.respondWith(
      caches.open(DICT_CACHE).then(function (cache) {
        return cache.match(req).then(function (hit) {
          if (hit) return hit;
          return fetch(req).then(function (res) {
            if (res && (res.ok || res.status === 404)) cache.put(req, res.clone());
            return res;
          });
        });
      })
    );
    return;
  }

  event.respondWith(
    fetch(req).then(function (res) {
      if (res && res.ok) {
        var copy = res.clone();
        caches.open(CACHE).then(function (cache) { cache.put(req, copy); });
      }
      return res;
    }).catch(function () {
      return caches.match(req, { ignoreSearch: true }).then(function (hit) {
        return hit || (req.mode === 'navigate' ? caches.match('./index.html') : undefined);
      });
    })
  );
});
