const path = require('path');
const webpack = require('webpack');
const { WebpackManifestPlugin } = require('webpack-manifest-plugin');

module.exports = {
  mode: 'production',
  entry: {
    index: './src/index.js'
  },
  output: {
    filename: '[name]-[fullhash].js',
    path: path.resolve(__dirname, 'assets'),
    clean: { keep: '.gitkeep' }
  },
  performance: {
    maxEntrypointSize: 512000,
    maxAssetSize: 512000
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
              ['@babel/preset-react', { runtime: 'classic' }],
              '@babel/preset-env'
            ],
            plugins: [['babel-plugin-polyfill-corejs3', { method: 'usage-global', version: require('core-js/package.json').version }], '@emotion']
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
    new webpack.IgnorePlugin({ resourceRegExp: /^\.\/locale$/, contextRegExp: /moment$/ }),
    new WebpackManifestPlugin({
      publicPath: ''
    })
  ],
};
