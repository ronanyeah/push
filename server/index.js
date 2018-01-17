const restify = require("restify");
const corsMiddleware = require("restify-cors-middleware");
const { pathOr, pipe, path } = require("ramda");
const { encase, of } = require("fluture");
const { parse } = require("url");

const {
  PUSH_PASSWORD,
  PORT,
  VAPID_PUBLIC_KEY,
  PUBLIC_FOLDER
} = require("./config.js");

const {
  removeSubscription,
  send,
  addSubscription
} = require("./utils/pushManagement.js");
const {
  bodyReader,
  sendFile,
  urlBase64ToIntArray,
  json
} = require("./utils/helpers.js");
const subscriptions = require("./db/subscriptions.js");

const pushKey = urlBase64ToIntArray(VAPID_PUBLIC_KEY);

const server = restify.createServer();

const cors = corsMiddleware({
  preflightMaxAge: 5,
  origins: ["*"],
  allowHeaders: [],
  exposeHeaders: []
});

server.pre(cors.preflight);
server.use(cors.actual);

server.get("/subscription", ({ url }, res, next) =>
  pipe(
    url => parse(url, true),
    path(["query", "endpoint"]),
    value =>
      value
        ? subscriptions
            .get(decodeURIComponent(value))
            .fork(
              err => next(new Error(err)),
              data => (data ? res.send(data) : next(new Error("oops")))
            )
        : next(new Error("oops"))
  )(url)
);

server.get("/ping", (_req, res) => res.send({ alive: true }));

server.get("/config", (_req, res) => res.send(pushKey));

server.post("/validate", (req, res) =>
  bodyReader(req)
    .chain(encase(JSON.parse))
    .chain(({ key, subscription = {} }) =>
      subscriptions
        .get(subscription.endpoint)
        .map(
          data =>
            String(pushKey) === String(key) &&
            data === JSON.stringify(subscription)
        )
    )
    .fork(
      err => next(new Error(err)),
      valid =>
        res.send({
          valid
        })
    )
);

server.post("/subscribe", (req, res, next) =>
  bodyReader(req)
    .chain(encase(JSON.parse))
    .chain(addSubscription)
    .fork(err => next(new Error(err)), _ => res.send({ status: "Subscribed!" }))
);

server.post("/push", (req, _res) =>
  bodyReader(req)
    .chain(encase(JSON.parse))
    .chain(
      ({ password, text = "" }) =>
        password === PUSH_PASSWORD
          ? send("Hey!", text)
          : of({ statusCode: 401 })
    )
    .fork(err => next(new Error(err)), _ => json({ status: "Pushed!" }))
);

server.put("/unsubscribe", (req, res) =>
  bodyReader(req)
    .chain(encase(JSON.parse))
    .chain(
      ({ subscriptionEndpoint }) =>
        subscriptionEndpoint ? removeSubscription(subscriptionEndpoint) : of()
    )
    .fork(
      err => next(new Error(err)),
      _ =>
        res.send({
          statusCode: 200
        })
    )
);

server.listen(PORT, () => console.log(`server listening on port: ${PORT}`));
