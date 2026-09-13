'use strict';

// Nombre del caché
const CACHE_NAME = 'parqueadero-calypso-cache-v1';

// Archivos que se van a cachear
const urlsToCache = [
  '/',
  'index.html',
  'main.dart.js',
  'manifest.json',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png'
];

// Instalar Service Worker y cachear archivos iniciales
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('✅ Archivos cacheados');
      return cache.addAll(urlsToCache);
    })
  );
});

// Activar Service Worker y limpiar cachés viejos
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('🗑️ Caché viejo eliminado:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

// Interceptar peticiones y servir desde cache si no hay internet
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      // Si el recurso está en caché, lo devuelve; si no, lo busca en la red
      return response || fetch(event.request);
    })
  );
});
