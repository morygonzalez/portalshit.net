#-*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Lokka::AmazonAssociate do
  before do
    FactoryGirl.create(:user, :name => 'test')
  end

  context "GET /admin/plugins/amazon_associate" do
    subject do
      get "/admin/plugins/amazon_associate"
      last_response
    end

    it "should be success" do
      subject.shuold be_success
    end

    it "should match \"Amazon Associate\"" do
      subject.body.should match('Amazon Associate')
    end
  end

  context "PUT /admin/plugins/amazon_associate" do
    before do
      put "/admin/plugins/amazon_associate",
        { :associate_tag => "portalshit-22",
          :access_key_id => "access_key_id",
          :secret_key => "secret_key" }
    end

    it "should be success" do
      last_response.should be_success
    end

    it "parameters should have correctly saved" do
      Option.associate_tag.should == "portalshit-22"
      Option.access_key_id.should == "access_key_id"
      Option.secret_key.shuold = "secret_key"
    end
  end
end
