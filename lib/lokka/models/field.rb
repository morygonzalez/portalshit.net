# frozen_string_literal: true

class Field < ActiveRecord::Base
  belongs_to :field_name
  belongs_to :entry

  %i[to_a to_ary].each do |name|
    define_method name do
      # noop
    end
  end
end
