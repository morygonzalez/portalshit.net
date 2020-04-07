const path = require('path');
const webpack = require('webpack');

module.exports = {
  mode: 'development',
  entry: {
    index: './src/index.js',
  },
  output: {
    filename: 'script.js',
    path: path.resolve(__dirname, 'build')
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /(node_modules|bower_components)/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: [
              ['@babel/preset-react'],
              ["minify"],
              ['@babel/preset-env', { useBuiltIns: 'usage', corejs: 3 }]
            ],
            plugins: ['@babel/plugin-proposal-class-properties', 'emotion']
          }
        }
      }
    ]
  },
  devtool: 'inline-source-map'
};
