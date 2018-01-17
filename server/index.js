const restify = require("restify");
const corsMiddleware = require("restify-cors-middleware");
const { pipe, path } = require("ramda");
const { of, reject } = require("fluture");
const { parse } = require("url");

const { PUSH_PASSWORD, PORT, VAPID_PUBLIC_KEY } = require("./config.js");

const { send, addSubscription } = require("./utils/pushManagement.js");
const { urlBase64ToIntArray } = require("./utils/helpers.js");
const subscriptions = require("./db/subscriptions.js");

const pushKey = urlBase64ToIntArray(VAPID_PUBLIC_KEY);

const server = restify.createServer();

const cors = corsMiddleware({
  preflightMaxAge: 5,
  origins: ["*"],
  allowHeaders: [],
  exposeHeaders: []
});

server.use(restify.plugins.bodyParser());
server.pre(cors.preflight);
server.use(cors.actual);

server.get("/subscription", (req, res) =>
  pipe(
    url => parse(url, true),
    path(["query", "endpoint"]),
    endpoint =>
      endpoint
        ? subscriptions
            .get(decodeURIComponent(endpoint))
            .fork(
              err => res.send(400, err),
              data =>
                data ? res.send(data) : res.send(400, "subscription not found!")
            )
        : res.send(400, "endpoint missing!")
  )(req.url)
);

server.get("/ping", (_req, res) => res.send({ alive: true }));

server.get("/config", (_req, res) => res.send(pushKey));

server.post("/validate", (req, res) =>
  of(path(["body", "subscription", "endpoint"], req))
    .chain(
      endpoint =>
        endpoint ? subscriptions.get(endpoint) : reject("endpoint missing!")
    )
    .map(
      data =>
        String(pushKey) === String(req.body.key) &&
        data === JSON.stringify(req.body.subscription)
    )
    .fork(
      err => res.send(400, err),
      valid =>
        res.send({
          valid
        })
    )
);

server.post("/subscribe", (req, res) =>
  addSubscription(req.body).fork(
    err => res.send(400, err),
    _ => res.send({ status: "Subscribed!" })
  )
);

server.post(
  "/push",
  (req, res) =>
    req.body.password === PUSH_PASSWORD
      ? send("Hey!", req.body.text).fork(
          err => res.send(400, err),
          _ => res.send({ status: "Pushed!" })
        )
      : res.send(401)
);

server.put("/unsubscribe", (req, res) =>
  subscriptions
    .delete(req.body.subscriptionEndpoint)
    .fork(err => res.send(400, err), _ => res.send(200))
);

server.listen(PORT, () => console.log(`server listening on port: ${PORT}`));
