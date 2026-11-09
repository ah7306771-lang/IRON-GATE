// IRON GATE — Service Worker (PWA + Push Notifications)
// نسخة كاملة تجمع الـcaching وإشعارات الـpush في ملف واحد

const CACHE = 'irongate-v2';  // غيّرت الـversion علشان المتصفحات تاخد النسخة الجديدة
const SHELL = ['./', './index.html', './manifest.json', './icons/icon-192.png', './icons/icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// network-first: always try the latest version, fall back to cache when offline
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  e.respondWith(
    fetch(req)
      .then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
        return res;
      })
      .catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
  );
});

// ============================================================
// 🔔 Push Notifications
// ============================================================

self.addEventListener('push', function (event) {
  var d = {};
  try { d = event.data ? event.data.json() : {}; }
  catch (_) { d = { body: event.data ? event.data.text() : '' }; }
  var title = d.title || 'IRON GATE';
  event.waitUntil(self.registration.showNotification(title, {
    body: d.body || '',
    icon: './icons/icon-192.png',
    badge: './icons/icon-192.png',
    tag: d.tag || 'ig-cheques',
    dir: 'rtl',
    lang: 'ar',
    data: { url: d.url || './' }
  }));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var url = (event.notification.data && event.notification.data.url) || './';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (var i = 0; i < list.length; i++) {
        if ('focus' in list[i]) return list[i].focus();
      }
      return self.clients.openWindow(url);
    })
  );
});