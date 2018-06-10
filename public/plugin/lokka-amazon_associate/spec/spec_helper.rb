# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path(File.dirname(__FILE__) + '/../Gemfile')
require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
Bundler.require :default if defined?(Bundler)

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'lokka/amazon_associate'
require 'active_support/all'
