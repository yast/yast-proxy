#!/usr/bin/env rspec
require_relative "test_helper"
require "yast"

Yast.import "Proxy"

describe "Yast::ProxyClass" do
  subject do
    Yast::Proxy
  end

  context "common Read-Export test" do
    before do
      expect(Yast::SCR).to receive(:Read).
        with(path(".sysconfig.proxy.HTTP_PROXY")).
        and_return "h"

      expect(Yast::SCR).to receive(:Read).
        with(path(".sysconfig.proxy.HTTPS_PROXY")).
        and_return "hs"

      expect(Yast::SCR).to receive(:Read).
        with(path(".sysconfig.proxy.FTP_PROXY")).
        and_return "f"

      expect(Yast::SCR).to receive(:Read).
        with(path(".sysconfig.proxy.NO_PROXY")).
        and_return nil

      expect(Yast::SCR).to receive(:Read).
        with(path(".sysconfig.proxy.PROXY_ENABLED")).
        and_return "yes"

      expect(Yast::SCR).to receive(:Read).
        with(path(".target.size"), "/root/.curlrc").
        and_return 42

      expect(Yast::SCR).to receive(:Read).
        with(path(".root.curlrc.\"--proxy-user\"")).
       and_return "user:pass"
    end

    describe "#Read" do
      it "reads /etc/sysconfig/proxy and /root/.curlrc via SCR" do
        expect(subject.Read).to be true
      end
    end

    describe "#Export" do
      it "returns an appropriate hash" do
        subject.Read
        expect(subject.Export).to eq({
          "enabled"        => true,
          "ftp_proxy"      => "f",
          "http_proxy"     => "h",
          "https_proxy"    => "hs",
          "no_proxy"       => "",
          "proxy_password" => "pass",
          "proxy_user"     => "user"
        })
      end
    end
  end
end
