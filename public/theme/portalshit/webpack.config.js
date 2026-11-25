const path = require('path');
const webpack = require('webpack');
const { WebpackManifestPlugin } = require('webpack-manifest-plugin');

module.exports = {
  mode: 'production',
  entry: {
    index: './src/index.js',
    chat: './src/chat/index.js',
    'not-found-search': { import: './src/not-found-search.js', filename: 'not-found-search.js' },
  },
  output: {
    filename: '[name]-[fullhash].js',
    path: path.resolve(__dirname, 'scripts'),
    clean: { keep: '.gitkeep' }
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /(node_modules|bower_components)/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: [['@babel/preset-react', { runtime: 'classic' }], '@babel/preset-env'],
            plugins: [['babel-plugin-polyfill-corejs3', { method: 'usage-global', version: require('core-js/package.json').version }]]
          }
        }
      },
      {
        test: /\.css$/i,
        use: ['style-loader', 'css-loader']
      }
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery'
    }),
    new WebpackManifestPlugin({
      publicPath: ''
    })
  ],
};
