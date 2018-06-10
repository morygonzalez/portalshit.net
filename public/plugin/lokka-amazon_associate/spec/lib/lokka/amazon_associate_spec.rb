# frozen_string_literal: true

require 'spec_helper'

describe Lokka::Helpers do
  let(:base_dir) do
    File.join(File.dirname(__FILE__), '../../../')
  end

  before do
    Amazon::Ecs.stub(:options=).and_return(true)
    fake_option = Class.new
    %i[associate_tag access_key_id secret_key].each do |method|
      fake_option.stub(method)
    end
    stub_const('Option', fake_option)
    Amazon::Ecs.stub(:item_lookup).with(item_id, []).and_return(
      JSON.parse(
        File.read(File.expand_path(File.join(base_dir, 'spec/fixtures/4341085239.json')))
      )
    )
  end

  describe '#associate_link' do
    before do
      class DummyClass
        include Lokka::Helpers
      end
    end

    subject do
      DummyClass.new
    end

    context '本文中にISBN/ASINタグがあればアフィリエイトリンクに変換する' do
      let(:item_id) do
        '4341085239'
      end

      it 'ISBN タグをリンクに変換する' do
        subject.associate_link("これはテストです。\n\n<!-- ISBN=4341085239 -->\n\n終わり。").should match(/amazon-image/)
      end

      it 'ASIN タグをリンクに変換する' do
        associate_link("これはテストです。\n\n<!-- ASIN=4341085239 -->\n\n終わり。")
      end
    end
  end

  describe '#format_item' do
    it 'json を HTML として出力する'
  end

  describe '#format_authors' do
    it "著者名を整形する'"
  end

  describe '#get_item' do
    it 'item_id とオプションを受け取って検索結果を返す'
  end

  describe '#get_path' do
    it 'item_id を受け取ってパスを返す'
  end

  describe '#parse_item' do
    it 'does something'
  end
end

# describe Lokka::AmazonAssociate do
#   before do
#     FactoryGirl.create(:user, :name => 'test')
#   end
#
#   context "GET /admin/plugins/amazon_associate" do
#     subject do
#       get "/admin/plugins/amazon_associate"
#       last_response
#     end
#
#     it "should be success" do
#       subject.shuold be_success
#     end
#
#     it "should match \"Amazon Associate\"" do
#       subject.body.should match('Amazon Associate')
#     end
#   end
#
#   context "PUT /admin/plugins/amazon_associate" do
#     before do
#       put "/admin/plugins/amazon_associate",
#       { :associate_tag => "portalshit-22",
#         :access_key_id => "access_key_id",
#         :secret_key => "secret_key" }
#       end
#
#       it "should be success" do
#         last_response.should be_success
#       end
#
#       it "parameters should have correctly saved" do
#         Option.associate_tag.should == "portalshit-22"
#         Option.access_key_id.should == "access_key_id"
#         Option.secret_key.shuold = "secret_key"
#       end
#     end
#   end
# end
