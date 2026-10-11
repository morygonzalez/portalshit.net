# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'admin entry validation' do
  include_context 'admin login'

  around do |example|
    I18n.with_locale(:en) { example.run }
  end

  %i[page post].each do |factory|
    context "for #{factory}" do
      let(:entry_class) { factory.to_s.classify.constantize }
      let(:path) { "/admin/#{factory.to_s.pluralize}" }
      let(:oversized_body) { "<p>山の写真</p>\n" * 4_000 + '</textarea><script>unwanted()</script>' }
      let(:form) { Nokogiri::HTML(last_response.body) }
      let(:message) do
        I18n.t('entry.errors.body_too_large', limit: 65_535, bytes: oversized_body.bytesize)
      end

      before do
        # Simulate the old production TEXT column without changing the test schema.
        allow(entry_class).to receive(:body_byte_limit).and_return(65_535)
      end

      it 'returns 422 on creation, displays the reason and retains the input without saving' do
        sample = attributes_for(factory, slug: 'too-large', title: '山のアルバム', body: oversized_body)

        expect { post path, factory => sample }.not_to change(entry_class, :count)

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include(message, '山のアルバム')
        expect(Digest::SHA256.hexdigest(form.at_css("##{factory}_body").text)).to eq(
          Digest::SHA256.hexdigest(oversized_body)
        )
        expect(form.css('script').map(&:text)).not_to include('unwanted()')
        expect(last_response.body).not_to include('#&lt;ActiveRecord::Error')
      end

      it 'returns 422 on update and retains the input while leaving the saved entry unchanged' do
        entry = create(factory, title: '保存済み', body: '元の本文')
        original_updated_at = entry.updated_at

        put "#{path}/#{entry.id}", factory => { title: '更新案', body: oversized_body }

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include(message, '更新案')
        expect(Digest::SHA256.hexdigest(form.at_css("##{factory}_body").text)).to eq(
          Digest::SHA256.hexdigest(oversized_body)
        )
        expect(entry.reload.raw_body).to eq('元の本文')
        expect(entry.title).to eq('保存済み')
        expect(entry.updated_at).to eq(original_updated_at)
      end

      it 'also returns 422 for existing validation errors on creation' do
        sample = attributes_for(factory, title: '', body: '入力した本文')

        expect { post path, factory => sample }.not_to change(entry_class, :count)

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('入力した本文', 'Title can&#39;t be blank')
      end

      it 'also returns 422 for existing validation errors on update' do
        entry = create(factory)
        original_title = entry.title

        put "#{path}/#{entry.id}", factory => { title: '' }

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('Title can&#39;t be blank')
        expect(entry.reload.title).to eq(original_title)
      end

      it 'saves a body at the byte limit normally' do
        body = '山' * 21_845
        sample = attributes_for(factory, slug: 'at-limit', body: body)

        post path, factory => sample

        expect(last_response).to be_redirect
        expect(entry_class.find_by!(slug: 'at-limit').raw_body).to eq(body)
      end

      it 'shows the byte limit and size in Japanese when Japanese is selected' do
        sample = attributes_for(factory, body: oversized_body)

        post path, { factory => sample }, { 'HTTP_ACCEPT_LANGUAGE' => 'ja' }

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include(
          I18n.t('entry.errors.body_too_large', locale: :ja, limit: 65_535, bytes: oversized_body.bytesize)
        )
      end
    end
  end
end
