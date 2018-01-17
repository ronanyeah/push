const assets = ["/", "/tux.png", "/bundle.js", "/manifest.json"].map(
  url => self.location.origin + url
);

self.addEventListener("fetch", e =>
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok && assets.includes(e.request.url)) {
          caches.open("tux-cache").then(cache => cache.put(e.request, res));
        }
        return res.clone();
      })
      .catch(err => caches.match(e.request).then(res => res || err))
  )
);

self.addEventListener("push", e =>
  e.waitUntil(
    self.registration.showNotification(e.data.json().title, {
      body: e.data.json().body,
      icon: "/tux.png",
      vibrate: [400, 200],
      tag: "no_idea_what_this_is"
    })
  )
);

self.addEventListener("notificationclick", event => event.notification.close());
