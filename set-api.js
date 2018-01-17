const { readFileSync, writeFileSync } = require("fs");

const { API } = process.env;

const template = readFileSync("./src/_redirects", "UTF8");

writeFileSync("./public/_redirects", template.replace("API", API));
