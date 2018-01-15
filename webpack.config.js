const copyWebpackPlugin = require("copy-webpack-plugin");
const { resolve } = require("path");
const webpack = require("webpack");

const { DEBUG, NODE_ENV } = process.env;

const publicFolder = resolve("./public");

module.exports = {
  entry: "./src/index.js",
  output: {
    path: publicFolder,
    filename: "bundle.js"
  },
  devServer: {
    contentBase: publicFolder
  },
  module: {
    rules: [
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: [
          {
            loader: "elm-webpack-loader",
            options: {
              cwd: __dirname,
              debug: DEBUG === "true",
              warn: NODE_ENV === "development"
            }
          }
        ]
      }
    ]
  },
  plugins: [new copyWebpackPlugin(["static"])]
};
