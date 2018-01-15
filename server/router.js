const { pathOr } = require("ramda");

const handlers = require("./handlers/index.js");

// String -> String -> Future Err Function
module.exports = (method, pathname) =>
  pathOr(handlers["GET"]["/fourOhFour"], [method, pathname], handlers);
