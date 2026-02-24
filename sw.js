const cacheName = 'class-manager-v1';
const assetsToCache = [
  './',
  './index.html',
  './imp.html',
  './manifest.json',
  './tap.png',
  './classmanager.mp4',
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css',
  'https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600;800&display=swap'
];

// Install Event: Caching the assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(cacheName).then((cache) => {
      console.log('Class Manager: Caching App Shell & Media');
      return cache.addAll(assetsToCache);
    })
  );
});

// Activate Event: Cleaning up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== cacheName).map((key) => caches.delete(key))
      );
    })
  );
});

// Fetch Event: Serving cached content when offline
self.addEventListener('fetch', (event) => {
// --- ADD THIS AT THE TOP OF THE FETCH EVENT IN sw.js ---
if (event.request.url.includes('supabase.co')) {
    return; // Tells the PWA to stay away from database/auth calls
}
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      return cachedResponse || fetch(event.request);
    })
  );
});