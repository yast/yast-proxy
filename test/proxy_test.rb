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
      subject.Import("enabled" => false)

      expect(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.root\.curlrc/), nil)
        .at_least(:once)
        .and_return true

      expect(subject.WriteCurlrc).to be true
    end

    it "writes proxy settings, and a comment, when proxy is enabled" do
      subject.Import("enabled"    => true,
                     "http_proxy" => "proxy.example.org:3128")

      expect(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.root\.curlrc\..*\."comment"/), /Changed/)
        .once.and_return true

      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc.\"--proxy\""), "proxy.example.org:3128")
        .once.and_return true

      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc.\"--noproxy\""), "localhost")
        .once.and_return true

      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.root\.curlrc/), nil)
        .and_return true

      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc"), nil)
        .once.and_return true

      expect(subject.WriteCurlrc).to be true
    end

    it "writes proxy settings, and a comment, when proxy is enabled via InstallInfConvertor" do
      subject.Import("enabled"        => true,
                     "http_proxy"     => "proxy.example.org:3128",
                     "proxy_user"     => nil,
                     "proxy_password" => nil)

      expect(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.root\.curlrc\..*\."comment"/), /Changed/)
        .once.and_return true

      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc.\"--proxy\""), "proxy.example.org:3128")
        .once.and_return true

      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc.\"--noproxy\""), "localhost")
        .once.and_return true

      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.root\.curlrc/), nil)
        .and_return true

      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc"), nil)
        .once.and_return true

      expect(subject.WriteCurlrc).to be true
    end

    it "writes a no-proxy setting" do
      subject.Import("enabled"    => true,
                     "http_proxy" => "proxy.example.org:3128",
                     "no_proxy"   => "example.org,example.com,localhost")
      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc.\"--noproxy\""),
          "example.org,example.com,localhost")
        .once.and_return true

      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.root\.curlrc/), anything)
        .and_return true

      expect(subject.WriteCurlrc).to be true
    end

    it "writes a no-proxy setting without spaces" do
      subject.Import("enabled"    => true,
                     "http_proxy" => "proxy.example.org:3128",
                     "no_proxy"   => "example.org, example.com, localhost")
      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc.\"--noproxy\""),
          "example.org,example.com,localhost")
        .once.and_return true

      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.root\.curlrc/), anything)
        .and_return true

      expect(subject.WriteCurlrc).to be true
    end

    it "escapes user name" do
      subject.Import("enabled"        => true,
                     "http_proxy"     => "proxy.example.org:3128",
                     "proxy_user"     => "User\\Domain",
                     "proxy_password" => "P")

      expect(Yast::SCR).to receive(:Write)
        .with(path(".root.curlrc.\"--proxy-user\""), "User\\\\Domain:P")
        .once.and_return true

      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.root\.curlrc/), anything)
        .and_return true

      expect(subject.WriteCurlrc).to be true
    end
  end

  context "common Read-Export test" do
    before do
      allow(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.proxy.HTTP_PROXY"))
        .and_return "h"

      allow(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.proxy.HTTPS_PROXY"))
        .and_return "hs"

      allow(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.proxy.FTP_PROXY"))
        .and_return "f"

      allow(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.proxy.NO_PROXY"))
        .and_return nil

      allow(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.proxy.PROXY_ENABLED"))
        .and_return "yes"

      allow(Yast::SCR).to receive(:Read)
        .with(path(".target.size"), "/root/.curlrc")
        .and_return 42

      allow(Yast::SCR).to receive(:Read)
        .with(path(".root.curlrc.\"--proxy-user\""))
        .and_return "user:pass"
    end

    describe "#Read" do
      it "reads /etc/sysconfig/proxy and /root/.curlrc via SCR" do
        expect(subject.Read).to be true
      end
    end

    describe "#Export" do
      it "returns an appropriate hash" do
        subject.Read
        expect(subject.Export).to eq(
          "enabled"        => true,
          "ftp_proxy"      => "f",
          "http_proxy"     => "h",
          "https_proxy"    => "hs",
          "no_proxy"       => "",
          "proxy_password" => "pass",
          "proxy_user"     => "user"
        )
      end

      it "returns limited hash when proxy is disabled" do
        subject.enabled = false

        expect(subject.Export).to eq(
          "enabled" => false
        )
      end
    end
  end
end
