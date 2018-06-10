# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(File.join(__dir__, '../../../', 'lib/lokka/ogp.rb'))

describe Lokka::OGP do
  subject(:app) do
    Class.new(Sinatra::Base) do
      register Lokka::OGP
    end
  end

  it { should respond_to(:twitter_card) }
  its(:twitter_card) { should respond_to(:to_meta_tags) }
end
