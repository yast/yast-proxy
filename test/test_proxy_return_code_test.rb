#!/usr/bin/env rspec
require_relative "test_helper"
require "yast"


describe "Yast::ProxyDialogsInclude" do
  subject do
    instance = Yast::Module.new
    Yast.include instance, "proxy/dialogs.rb"
    instance
  end

  let(:datadir) { File.expand_path("../data", __FILE__) }

  describe "#TestProxyReturnCode" do
    it "returns truthy (without pop-up) for a good response" do
      proxy_kind = "HTTP"
      stderr = File.read(datadir + "/curl-stderr-good")

      expect(subject).to_not receive(:ErrorPopupGeneric)
      expect(!! subject.TestProxyReturnCode(proxy_kind, stderr)).to eq true
    end

    it "returns falsey (with pop-up) for a bad response at destination" do
      proxy_kind = "HTTP"
      stderr = File.read(datadir + "/curl-stderr-notfound")

      expect(subject).
        to receive(:ErrorPopupGeneric).
        with(kind_of(String), kind_of(String))
      expect(!! subject.TestProxyReturnCode(proxy_kind, stderr)).to eq false
    end

    it "returns falsey (with pop-up) for a bad response at proxy" do
      proxy_kind = "HTTP"
      stderr = File.read(datadir + "/curl-stderr-badproxy")

      expect(subject).
        to receive(:ErrorPopupGeneric).
        with(kind_of(String), kind_of(String))
      expect(!! subject.TestProxyReturnCode(proxy_kind, stderr)).to eq false
    end
  end
end
