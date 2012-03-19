#-*- coding: utf-8 -*-

describe Lokka::AmazonAssociate do
  include_context 'admin login'

  context "GET /admin/plugins/amazon_associate" do
    it "should be success" do
      get "/admin/plugins/amazon_associate"
      response.should be_success
    end
  end

  context "POST /admin/plugins/amazon_associate" do
    post "/admin/plugins/amazon_associate",
      { :associate_tag => "portalshit-22",
        :access_key_id => "access_key_id",
        :secret_key => "secret_key" }
  end
end
