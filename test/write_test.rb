#!/usr/bin/env rspec
require_relative "test_helper"
require "yast"

Yast.import "Proxy"

describe "Yast::ProxyClass" do
  subject do
    Yast::Proxy
  end

  describe "#WriteCurlrc" do
    it "deletes proxy entries, when proxy is disabled" do
      subject.Import({"enabled" => false})

      expect(Yast::SCR).to receive(:Write).
        with(path_matching(/^\.root\.curlrc/), nil).
        at_least(:once).
        and_return true

      expect(subject.WriteCurlrc).to be true
    end

    it "writes proxy settings, and a comment, when proxy is enabled" do
      subject.Import({ "enabled"    => true,
                       "http_proxy" => "proxy.example.org:3128" })

      expect(Yast::SCR).to receive(:Write).
        with(path_matching(/^\.root\.curlrc\..*\."comment"/), /Changed/).
        once.and_return true

      expect(Yast::SCR).to receive(:Write).
        with(path(".root.curlrc.\"--proxy\""), "proxy.example.org:3128").
        once.and_return true

      expect(Yast::SCR).to receive(:Write).
        with(path(".root.curlrc.\"--noproxy\""), "localhost").
        once.and_return true

      allow(Yast::SCR).to receive(:Write).
        with(path_matching(/^\.root\.curlrc/), nil).
        and_return true

      expect(Yast::SCR).to receive(:Write).
        with(path(".root.curlrc"), nil).
        once.and_return true

      expect(subject.WriteCurlrc).to be true
    end

    it "writes a no-proxy setting" do
      subject.Import({ "enabled"    => true,
                       "http_proxy" => "proxy.example.org:3128",
                       "no_proxy"   => "example.org,example.com,localhost" })
      expect(Yast::SCR).to receive(:Write).
        with(path(".root.curlrc.\"--noproxy\""),
             "example.org,example.com,localhost").
        once.and_return true

      allow(Yast::SCR).to receive(:Write).
        with(path_matching(/^\.root\.curlrc/), anything).
        and_return true

      expect(subject.WriteCurlrc).to be true
    end

    it "escapes user name" do
      subject.Import({ "enabled"        => true,
                       "http_proxy"     => "proxy.example.org:3128",
                       "proxy_user"     => "User\\Domain",
                       "proxy_password" => "P" })

      expect(Yast::SCR).to receive(:Write).
        with(path(".root.curlrc.\"--proxy-user\""), "User\\\\Domain:P").
        once.and_return true

      allow(Yast::SCR).to receive(:Write).
        with(path_matching(/^\.root\.curlrc/), anything).
        and_return true

      expect(subject.WriteCurlrc).to be true
    end
  end
end
