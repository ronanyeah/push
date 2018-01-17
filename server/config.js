const {
  VAPID_PUBLIC_KEY,
  VAPID_PRIVATE_KEY,
  PUSH_PASSWORD,
  MY_EMAIL,
  REDIS_URL
} = process.env;

if (
  !VAPID_PUBLIC_KEY ||
  !VAPID_PRIVATE_KEY ||
  !PUSH_PASSWORD ||
  !MY_EMAIL ||
  !REDIS_URL
) {
  // Keys are from require('web-push').generateVAPIDKeys().
  // Password can be anything.
  throw Error("Push environment variable missing!");
}

module.exports = {
  MY_EMAIL,
  VAPID_PUBLIC_KEY,
  VAPID_PRIVATE_KEY,
  PUSH_PASSWORD,
  REDIS_URL,
  PORT: process.env.PORT || 3000
};
