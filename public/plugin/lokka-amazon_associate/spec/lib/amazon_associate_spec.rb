# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Lokka::Helpers do
  describe '#associate_link' do
    context '本文中にISBN/ASINタグがあればアフィリエイトリンクに変換する' do
      it 'ISBN タグをリンクに変換する' do
        associate_link("これはテストです。\n\n<!-- ISBN=UNKOSHITAIYO -->\n\n終わり。").should match(/amazon-image/)
      end

      it 'ASIN タグをリンクに変換する' do
        associate_link("これはテストです。\n\n<!-- ASIN=UNKOSHITAIYO -->\n\n終わり。").should
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
