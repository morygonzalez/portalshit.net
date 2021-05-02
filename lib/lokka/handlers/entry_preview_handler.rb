# frozen_string_literal: true

module Lokka
  class EntryPreviewHandler
    attr_reader :params, :default_markup

    def initialize(params, default_markup = 'html')
      @params = params
      @default_markup = default_markup
    end

    def handle
      {
        message: 'Preview successfull',
        body: body,
        markup: entry.markup,
        status: 201
      }
    rescue StandardError => e
      {
        message: e.message,
        backtrace: e.backtrace,
        status: 500
      }
    end

    private

    def entry
      @entry ||= Entry.new(markup: params[:markup], body: params[:raw_body])
    end

    def body
      Lokka::Helpers.expand_associate_link(entry.body)
    end
  end
end
