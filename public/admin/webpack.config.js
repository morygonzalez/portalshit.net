const path = require('path');
const webpack = require('webpack');

module.exports = {
  entry: {
    index: './js/src/index.js',
    jquery: './js/src/jquery.js'
  },
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, 'js')
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
              '@babel/preset-env'
            ],
            plugins: [['babel-plugin-polyfill-corejs3', { method: 'usage-global', version: require('core-js/package.json').version }]]
          },
        }
      }
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery'
    })
  ],
  mode: 'production'
};
