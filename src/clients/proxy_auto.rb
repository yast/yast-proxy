# encoding: utf-8

# File:	clients/proxy_auto.ycp
# Package:	Network configuration
# Summary:	Client for autoinstallation
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param function to execute
# @param map/list of proxy settings
# @return [Hash] edited settings, Summary or boolean on success depending on called function
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallFunction ("proxy_auto", [ "Summary", mm ]);
module Yast
  class ProxyAutoClient < Client
    def main
      Yast.import "UI"

      textdomain "proxy"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Proxy auto started")

      Yast.import "Proxy"
      Yast.import "Wizard"
      Yast.import "Summary"

      Yast.include self, "proxy/dialogs.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Create a summary
      if @func == "Summary"
        @ret = ProxySummary()
      # Reset configuration
      elsif @func == "Reset"
        Proxy.Import({})
        @ret = {}
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        Wizard.CreateDialog
        Wizard.SetDesktopTitleAndIcon("proxy")
        @ret = ProxyMainDialog(true)
        UI.CloseDialog
      # return required package list
      elsif @func == "Packages"
        @ret = {}
      # Import configuration
      elsif @func == "Import"
        @ret = Proxy.Import(@param)
      elsif @func == "SetModified"
        @ret = Proxy.SetModified
      elsif @func == "GetModified"
        @ret = Proxy.GetModified
      # Read configuration (useful for cloning)
      elsif @func == "Read"
        @ret = Proxy.Read
      # Return actual state
      elsif @func == "Export"
        @ret = Proxy.Export
      # Write givven settings
      elsif @func == "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        Proxy.write_only = true
        @ret = Proxy.Write
        Progress.set(@progress_orig)
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Proxy auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      Proxy.modified
    end
    def ProxySummary
      summary = ""
      nc = Summary.NotConfigured
      summary = Summary.AddHeader(summary, _("Status of Proxy Configuration"))
      summary = Summary.AddLine(summary, Proxy.enabled ? _("Enabled") : nc)
      if Proxy.http != ""
        summary = Summary.AddHeader(summary, _("HTTP"))
        summary = Summary.AddLine(summary, Proxy.http)
      end
      if Proxy.https != ""
        summary = Summary.AddHeader(summary, _("HTTPS"))
        summary = Summary.AddLine(summary, Proxy.https)
      end
      if Proxy.ftp != ""
        summary = Summary.AddHeader(summary, _("FTP"))
        summary = Summary.AddLine(summary, Proxy.ftp)
      end
      summary
    end
  end
end

Yast::ProxyAutoClient.new.main
