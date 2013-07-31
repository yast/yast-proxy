# encoding: utf-8

module Yast
  class ProxyClient < Client
    def main
      Yast.include self, "testsuite.rb"

      @READ = {
        "root"      => { "curlrc" => { "--proxy-user" => "user:pass" } },
        "sysconfig" => {
          "proxy"    => {
            "PROXY_ENABLED" => nil,
            "HTTP_PROXY"    => "h",
            "HTTPS_PROXY"   => "h",
            "FTP_PROXY"     => "f"
          },
          "language" => {
            "RC_LANG"          => "",
            "DEFAULT_LANGUAGE" => "",
            "ROOT_USES_LANG"   => "no"
          },
          "console"  => { "CONSOLE_ENCODING" => "UTF-8" }
        },
        "probe"     => { "system" => [] },
        "target"    => { "size" => 1, "tmpdir" => "/tmp" },
        "product"   => {
          "features" => {
            "USE_DESKTOP_SCHEDULER" => "0",
            "ENABLE_AUTOLOGIN"      => "0",
            "EVMS_CONFIG"           => "0",
            "IO_SCHEDULER"          => "cfg",
            "UI_MODE"               => "expert"
          }
        }
      }

      @EXEC = { "target" => { "bash_output" => {} } }

      TESTSUITE_INIT([@READ, {}, @EXEC], nil)

      Yast.import "Proxy"
      Yast.import "Progress"
      Progress.off

      DUMP("Read")
      TEST(lambda { Proxy.Read }, [@READ], nil)

      DUMP("Write")
      #TEST(``(Proxy::Write()), [], nil);

      @lan_settings = {
        "dns"        => {
          "dhcp_hostname" => false,
          "domain"        => "suse.com",
          "hostname"      => "nashif",
          "nameservers"   => ["10.0.0.1"],
          "searchlist"    => ["suse.com"]
        },
        "interfaces" => [
          {
            "STARTMODE" => "onboot",
            "BOOTPROTO" => "static",
            "BROADCAST" => "10.10.1.255",
            "IPADDR"    => "10.10.1.1",
            "NETMASK"   => "255.255.255.0",
            "NETWORK"   => "10.10.1.0",
            "UNIQUE"    => "",
            "device"    => "eth0",
            "module"    => "",
            "options"   => ""
          }
        ],
        "routing"    => {
          "routes"        => [
            {
              "destination" => "default",
              "device"      => "",
              "gateway"     => "10.10.0.8",
              "netmask"     => "0.0.0.0"
            }
          ],
          "ip_forwarding" => false
        }
      }

      DUMP("Import")
      #TEST(``(Proxy::Import(lan_settings)), [], nil);

      DUMP("Export")
      TEST(lambda { Proxy.Export }, [], nil)

      nil
    end
  end
end

Yast::ProxyClient.new.main
