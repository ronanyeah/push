const { node } = require("fluture");
const { __, prop, propOr, pipe, invoker } = require("ramda");
const hl = require("highland");
const joi = require("joi");

// Request -> Future Err Body
const bodyReader = req => node(done => hl(req).toCallback(done));

// Number -> [Number]
const range = pipe(Array, invoker(0, "keys"), Array.from);

// From: https://github.com/web-push-libs/web-push
// String -> [Number]
const urlBase64ToIntArray = base64String => {
  const padding = "=".repeat((4 - base64String.length % 4) % 4);
  const rawData = Buffer.from(
    (base64String + padding).replace(/-/g, "+").replace(/_/g, "/"),
    "base64"
  ).toString("binary");

  return range(rawData.length).map(index => rawData.charCodeAt(index));
};

// a -> Future Err a
const validateSubscription = sub =>
  node(done =>
    joi.validate(
      sub,
      joi
        .object()
        .keys({
          endpoint: joi.string(),
          keys: joi
            .object()
            .keys({
              p256dh: joi.string(),
              auth: joi.string()
            })
            .requiredKeys("p256dh", "auth")
        })
        .requiredKeys("endpoint", "keys"),
      done
    )
  );

const json = data => ({
  payload: JSON.stringify(data),
  statusCode: 200,
  contentType: "application/json"
});

module.exports = {
  validateSubscription,
  bodyReader,
  range,
  json,
  urlBase64ToIntArray
};
