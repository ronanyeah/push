if (navigator.serviceWorker) {
  navigator.serviceWorker
    .register("/sw.js")
    .then(console.log)
    .catch(alert);
}

const Elm = require("./Tux.elm");

const app = Elm.Tux.fullscreen(localStorage.getItem("tux-model") || "");

// PUSH SUBSCRIBE
app.ports.pushSubscribe.subscribe(key =>
  navigator.serviceWorker.ready
    .then(reg =>
      reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: new Uint8Array(key)
      })
    )
    .then(subscription =>
      app.ports.pushSubscription.send(subscription.toJSON())
    )
    .catch(alert)
);

// PUSH UNSUBSCRIBE
app.ports.pushUnsubscribe.subscribe(() =>
  navigator.serviceWorker.ready
    .then(reg => reg.pushManager.getSubscription())
    .then(
      subscription =>
        subscription ? subscription.unsubscribe() : Promise.resolve()
    )
    .then(() => app.ports.pushSubscription.send(null))
    .catch(alert)
);

// SAVE STATE
app.ports.setStorage.subscribe(state =>
  localStorage.setItem("tux-model", JSON.stringify(state))
);
