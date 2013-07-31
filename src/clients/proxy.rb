# encoding: utf-8

# File:	clients/proxy.ycp
# Package:	Network configuration
# Summary:	Proxy client
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
#
# Main file for proxy configuration.
# Uses all other files.
module Yast
  class ProxyClient < Client
    def main
      Yast.import "UI"

      textdomain "proxy"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Proxy module started")

      Yast.import "CommandLine"
      Yast.import "Label"
      Yast.import "Proxy"
      Yast.import "Wizard"

      Yast.include self, "proxy/dialogs.rb"

      @cmdline = {
        # Commandline help title
        "help"       => _("Proxy Configuration"),
        "id"         => "proxy",
        "guihandler" => fun_ref(method(:ProxyGUI), "any ()"),
        "initialize" => fun_ref(Proxy.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Proxy.method(:Write), "boolean ()"),
        "actions"    => {
          "enable"         => {
            # command-line help
            "help"    => _("Enable proxy settings"),
            "handler" => fun_ref(
              method(:EnableHandler),
              "boolean (map <string, string>)"
            )
          },
          "disable"        => {
            # command-line help
            "help"    => _("Disable proxy settings"),
            "handler" => fun_ref(
              method(:DisableHandler),
              "boolean (map <string, string>)"
            )
          },
          "set"            => {
            # command-line help
            "help"    => _(
              "Change the current proxy settings"
            ),
            "handler" => fun_ref(
              method(:SetHandler),
              "boolean (map <string, string>)"
            )
          },
          "authentication" => {
            # command-line help
            "help"    => _(
              "Set the authentication for proxy"
            ),
            "handler" => fun_ref(
              method(:AuthHandler),
              "boolean (map <string, string>)"
            )
          },
          "summary"        => {
            # command-line help
            "help"    => _(
              "Show the summary of the current settings"
            ),
            "handler" => fun_ref(
              method(:SummaryHandler),
              "boolean (map <string, string>)"
            )
          }
        },
        "options"    => {
          "http"     => {
            # command-line option help
            "help" => _("Set HTTP proxy"),
            "type" => "string"
          },
          "https"    => {
            # command-line option help
            "help" => _("Set HTTPS proxy"),
            "type" => "string"
          },
          "ftp"      => {
            # command-line option help
            "help" => _("Set FTP proxy"),
            "type" => "string"
          },
          "clear"    => {
            # command-line option help
            "help" => _("Clear all options listed")
          },
          "noproxy"  => {
            # command-line option help
            "help" => _(
              "Set domains for not using the proxy settings"
            ),
            "type" => "string"
          },
          "username" => {
            # command-line option help
            "help" => _(
              "The username to be used for proxy authentication"
            ),
            "type" => "string"
          },
          "password" => {
            # command-line option help
            "help" => _(
              "The password to be used for proxy authentication"
            ),
            "type" => "string"
          }
        },
        "mappings"   => {
          "enable"         => [],
          "disable"        => [],
          "summary"        => [],
          "set"            => ["http", "https", "ftp", "noproxy", "clear"],
          "authentication" => ["username", "password", "clear"]
        }
      }

      @ret = CommandLine.Run(@cmdline)

      # Finish
      Builtins.y2milestone("Proxy module finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      Proxy.modified
    end

    def ProxyGUI
      Proxy.Read

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("proxy")
      Wizard.SetNextButton(:next, Label.FinishButton)

      # main ui function
      ret = ProxyMainDialog(true)
      Builtins.y2debug("ret == %1", ret)

      Proxy.Write if ret == :next && Modified()

      UI.CloseDialog

      deep_copy(ret)
    end

    def EnableHandler(options)
      options = deep_copy(options)
      Proxy.enabled = true
      Proxy.modified = true
      true
    end

    def DisableHandler(options)
      options = deep_copy(options)
      Proxy.enabled = false
      Proxy.modified = true
      true
    end

    def SetHandler(options)
      options = deep_copy(options)
      clear = Builtins.haskey(options, "clear")

      # TODO: maybe we should validate the values
      Builtins.foreach(options) do |option, value|
        case option
          when "http"
            Builtins.y2milestone(
              "Setting HTTP proxy to '%1'",
              clear ? "" : option
            )
            Proxy.http = clear ? "" : value
            Proxy.modified = true
          when "https"
            Builtins.y2milestone(
              "Setting HTTPS proxy to '%1'",
              clear ? "" : option
            )
            Proxy.https = clear ? "" : value
            Proxy.modified = true
          when "ftp"
            Builtins.y2milestone(
              "Setting FTP proxy to '%1'",
              clear ? "" : option
            )
            Proxy.ftp = clear ? "" : value
            Proxy.modified = true
          when "noproxy"
            Builtins.y2milestone(
              "Setting NO proxy to '%1'",
              clear ? "" : option
            )
            Proxy.no = clear ? "" : value
            Proxy.modified = true
        end
      end

      true
    end

    def AuthHandler(options)
      options = deep_copy(options)
      if Builtins.haskey(options, "clear")
        Proxy.user = ""
        Proxy.pass = ""
      else
        Proxy.user = Ops.get(options, "username", "")
        Proxy.pass = Ops.get(options, "password")

        if Proxy.pass == nil
          # ask the user

          # translators: command line prompt for entering a password
          Proxy.pass = CommandLine.PasswordInput(_("Password:"))
        end
      end
      true
    end

    def SummaryHandler(options)
      options = deep_copy(options)
      Yast.import "RichText"

      CommandLine.Print(RichText.Rich2Plain(Proxy.Summary))
      true
    end
  end
end

Yast::ProxyClient.new.main
