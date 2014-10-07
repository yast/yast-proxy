# encoding: utf-8

# File:	modules/Proxy.ycp
# Package:	Network configuration
# Summary:	Proxy data
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
#
# Configures FTP and HTTP proxies via sysconfig & SuSEconfig
# and /root/.curlrc (for YOU)
require "yast"

module Yast
  class ProxyClass < Module
    def main
      textdomain "proxy"

      Yast.import "Summary"
      Yast.import "Progress"
      Yast.import "Mode"
      Yast.import "Popup"

      @proposal_valid = false
      @write_only = false

      # Data was modified?
      @modified = false

      @enabled = false
      @http = ""
      @https = ""
      @ftp = ""
      @no = ""
      @user = ""
      @pass = ""
    end

    # Display popup at the end of the proxy configuration
    # @param [Boolean] modified true if proxy settings have been modified
    def ProxyFinishPopup(modified)
      return if !modified

      # Popup headline
      head = _("Proxy Configuration Successfully Saved")
      text = _(
        "It is recommended to relogin to make new proxy settings effective."
      )
      Popup.AnyMessage(head, text)

      nil
    end

    # Create comment for changed file
    # @param [String] modul YaST2 module changing the file
    # @return comment
    # @example ChangedComment("lan") -> # Changed by YaST2 module lan 1.1.2000"
    def ChangedComment(modul)
      ret = "\n# Changed by YaST2"
      if modul != nil && modul != ""
        ret = Ops.add(ret + " module ", modul)
      end
      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/bin/date '+%x'")
      )
      date = Ops.get_string(out, "stdout", "")
      ret = Ops.add(Ops.add(ret, " "), date) if date != ""
      ret
    end

    # Read settings
    # @return true if success
    def Read
      # Read /etc/sysconfig/proxy
      @http = Convert.to_string(SCR.Read(path(".sysconfig.proxy.HTTP_PROXY")))
      @http = "" if @http == nil
      @https = Convert.to_string(SCR.Read(path(".sysconfig.proxy.HTTPS_PROXY")))
      @https = "" if @https == nil
      @ftp = Convert.to_string(SCR.Read(path(".sysconfig.proxy.FTP_PROXY")))
      @ftp = "" if @ftp == nil
      @no = Convert.to_string(SCR.Read(path(".sysconfig.proxy.NO_PROXY")))
      @no = "" if @no == nil
      @enabled = Convert.to_string(
        SCR.Read(path(".sysconfig.proxy.PROXY_ENABLED"))
      ) != "no"

      # Read /root/.curlrc
      if Ops.greater_than(SCR.Read(path(".target.size"), "/root/.curlrc"), 0)
        @user = Convert.to_string(
          SCR.Read(Builtins.add(path(".root.curlrc"), "--proxy-user"))
        )
      end

      @user = "" if @user == nil

      if Builtins.issubstring(@user, ":")
        @pass = Builtins.regexpsub(@user, "^.*:(.*)$", "\\1")
        @user = Builtins.regexpsub(@user, "^(.*):.*$", "\\1")
      end

      @pass = "" if @pass == nil
      if @user == nil
        @user = ""
      else
        if Builtins.regexpmatch(@user, "^.*\\\\.*$")
          @user = Builtins.regexpsub(@user, "^(.*)\\\\(.*)$", "\\1\\2")
        end
      end

      # Read /root/.wgetrc
      # YOU uses curl(1)
      # user = SCR::Read(.root.wgetrc.proxy_user);
      # if(user == nil) user = "";
      # pass = SCR::Read(.root.wgetrc.proxy_passwd);
      # if(pass == nil) pass = "";

      true
    end

    # Write routing settings and apply changes
    # @return true if success
    def Write
      Builtins.y2milestone("Writing configuration")
      if !@modified
        Builtins.y2milestone(
          "No changes to proxy configuration -> nothing to write"
        )
        return true
      end

      steps = [_("Update proxy configuration")]

      caption = _("Saving Proxy Configuration")
      # sleep for longer time, so that progress does not disappear right afterwards
      # but only when Progress is visible
      sl = Progress.status == true ? 500 : 0

      Progress.New(caption, " ", Builtins.size(steps), steps, [], "")

      Progress.NextStage
      Progress.Title(_("Updating proxy configuration..."))

      # Update /etc/sysconfig/proxy
      SCR.Write(path(".sysconfig.proxy.PROXY_ENABLED"), @enabled ? "yes" : "no")
      SCR.Write(path(".sysconfig.proxy.HTTP_PROXY"), @http)
      SCR.Write(path(".sysconfig.proxy.HTTPS_PROXY"), @https)
      SCR.Write(path(".sysconfig.proxy.FTP_PROXY"), @ftp)
      SCR.Write(path(".sysconfig.proxy.NO_PROXY"), @no)
      SCR.Write(path(".sysconfig.proxy"), nil)

      # proxy is used, write /root/.curlrc
      # bugzilla #305163
      if @enabled
        # Update /root/.curlrc
        proxyuser = nil
        if @user != ""
          #Escape backslash characters in .curlrc (#331038)
          @user = Builtins.mergestring(
            Builtins.splitstring(@user, "\\"),
            "\\\\"
          )
          proxyuser = @user
          proxyuser = Ops.add(Ops.add(@user, ":"), @pass) if @pass != ""
        end

        # nil or real value
        SCR.Write(Builtins.add(path(".root.curlrc"), "--proxy-user"), proxyuser)

        # not 'nil', not empty
        # bugzilla #305163
        if @http != nil && Ops.greater_than(Builtins.size(@http), 0)
          SCR.Write(Builtins.add(path(".root.curlrc"), "--proxy"), @http)
        else
          SCR.Write(Builtins.add(path(".root.curlrc"), "--proxy"), nil)
        end

        # only written value can have a comment
        if proxyuser != nil
          SCR.Write(
            Builtins.add(
              Builtins.add(path(".root.curlrc"), "--proxy-user"),
              "comment"
            ),
            ChangedComment("proxy")
          ) 
          # only when set, can have a comment
        elsif @http != nil && Ops.greater_than(Builtins.size(@http), 0)
          SCR.Write(
            Builtins.add(
              Builtins.add(path(".root.curlrc"), "--proxy"),
              "comment"
            ),
            ChangedComment("proxy")
          )
        end 
        # proxy is not used, remove proxy-related settings
      else
        SCR.Write(Builtins.add(path(".root.curlrc"), "--proxy-user"), nil)
        SCR.Write(Builtins.add(path(".root.curlrc"), "--proxy"), nil)
      end

      SCR.Write(path(".root.curlrc"), nil)
      Builtins.sleep(sl)
      Progress.NextStage

      #user can't relogin in installation and update, do not show the msg then (bnc#486037, bnc#543469)
      ProxyFinishPopup(true) if Mode.normal

      # Update /root/.wgetrc
      # YOU uses curl(1)
      # SCR::Write(.root.wgetrc.proxy_user, user);
      # SCR::Write(.root.wgetrc.proxy_passwd, pass);
      # SCR::Write(.root.wgetrc, nil);

      @modified = false

      true
    end


    # Get all settings from a map.
    # When called by <name>_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash] settings autoinstallation settings
    # @return true if success
    def Import(settings)
      settings = deep_copy(settings)
      @enabled = Ops.get_boolean(settings, "enabled", false)
      @http = Ops.get_string(settings, "http_proxy", "")
      @https = Ops.get_string(settings, "https_proxy", "")
      @ftp = Ops.get_string(settings, "ftp_proxy", "")
      @no = Ops.get_string(settings, "no_proxy", "localhost")
      @user = Ops.get_string(settings, "proxy_user", "")
      @pass = Ops.get_string(settings, "proxy_password", "")

      @modified = true
      true
    end

    # Runs tests of the HTTP and FTP proxy
    #
    # @param [String] http_proxy	such as "http://cache.example.com:3128"
    # @param [String] https_proxy	such as "http://cache.example.com:3128"
    # @param [String] ftp_proxy	such as "http://cache.example.com:3128"
    # @param [String] proxy_user	such as "proxy-username"
    # @param [String] proxy_password	such as "proxy-password"
    #
    # @return [Hash <String, Hash{String => Object>}] with results of the test
    #
    # **Structure:**
    #
    #     return = $[
    #     	"HTTP" : $[
    #     		"exit" : _exit_code,
    #     		"stdout" : _stdout,
    #     		"stderr" : _stderr,
    #     	],
    #     	"HTTPS" : $[
    #     		"exit" : _exit_code,
    #     		"stdout" : _stdout,
    #     		"stderr" : _stderr,
    #     	],
    #     	"FTP" : $[
    #     		"exit" : _exit_code,
    #     		"stdout" : _stdout,
    #     		"stderr" : _stderr,
    #     	],
    #      ]
    def RunTestProxy(http_proxy, https_proxy, ftp_proxy, proxy_user, proxy_password)
      # /usr/bin/curl --verbose
      # --proxy http://server_name:port_number
      # --proxy-user user:password
      # --url http://www.novell.com or ftp://ftp.novell.com | suggested for HTTP or FTP test
      # --url https://secure-www.novell.com --insecure
      ret = {}

      test_http = http_proxy != "" && http_proxy != "http://" ? true : false
      test_https = https_proxy != "" && https_proxy != "http://" ? true : false
      test_ftp = ftp_proxy != "" && ftp_proxy != "http://" ? true : false

      http_proxy = Builtins.mergestring(
        Builtins.splitstring(http_proxy, "\""),
        "\\\""
      )
      https_proxy = Builtins.mergestring(
        Builtins.splitstring(https_proxy, "\""),
        "\\\""
      )
      ftp_proxy = Builtins.mergestring(
        Builtins.splitstring(ftp_proxy, "\""),
        "\\\""
      )
      proxy_user = Builtins.mergestring(
        Builtins.splitstring(proxy_user, "\""),
        "\\\""
      )
      #escape also '\' character - usernames such as domain\user are causing pain to .target.bash_output
      #and to curl - #256360
      proxy_user = Builtins.mergestring(
        Builtins.splitstring(proxy_user, "\\"),
        "\\\\"
      )
      proxy_password = Builtins.mergestring(
        Builtins.splitstring(proxy_password, "\""),
        "\\\""
      )

      # enclose user:password into quotes, it may contain special characters (#338264)
      user_pass = proxy_user != "" ?
        Ops.add(
          Ops.add(
            Ops.add(" --proxy-user '", proxy_user),
            proxy_password != "" ? Ops.add(":", proxy_password) : ""
          ),
          "'"
        ) :
        ""

      # timeout for the connection
      timeout_sec = 90
      # %1 = http or ftp proxy, %2 = user:password if any, %3 = URL
      command = "curl --verbose --proxy %1 %2 --connect-timeout %3 --url %4"
      http_command = Builtins.sformat(
        command,
        http_proxy,
        user_pass,
        timeout_sec,
        "http://www.novell.com"
      )
      # adding option --insecure to accept the certificate without asking
      https_command = Builtins.sformat(
        command,
        https_proxy,
        user_pass,
        timeout_sec,
        "https://secure-www.novell.com --insecure"
      )
      ftp_command = Builtins.sformat(
        command,
        ftp_proxy,
        user_pass,
        timeout_sec,
        "ftp://ftp.novell.com"
      )

      Builtins.y2milestone("Running HTTP_PROXY test...")
      if test_http
        Builtins.y2milestone("Testing HTTP proxy %1", http_proxy)
        Ops.set(
          ret,
          "HTTP",
          Convert.convert(
            SCR.Execute(path(".target.bash_output"), http_command),
            :from => "any",
            :to   => "map <string, any>"
          )
        )
      else
        Builtins.y2milestone("Skipping HTTP Proxy test, no proxy used.")
        Ops.set(
          ret,
          "HTTP",
          { "exit" => 0, "stderr" => "", "stdout" => "", "tested" => false }
        )
      end
      Builtins.y2milestone("Done.")

      Builtins.y2milestone("Running HTTPS_PROXY test...")
      if test_https
        Builtins.y2milestone("Testing HTTPS proxy %1", https_proxy)
        Ops.set(
          ret,
          "HTTPS",
          Convert.convert(
            SCR.Execute(path(".target.bash_output"), https_command),
            :from => "any",
            :to   => "map <string, any>"
          )
        )
      else
        Builtins.y2milestone("Skipping HTTPS Proxy test, no proxy used.")
        Ops.set(
          ret,
          "HTTPS",
          { "exit" => 0, "stderr" => "", "stdout" => "", "tested" => false }
        )
      end
      Builtins.y2milestone("Done.")

      Builtins.y2milestone("Running FTP_PROXY test...")
      if test_ftp
        Builtins.y2milestone("Testing FTP proxy %1", ftp_proxy)
        Ops.set(
          ret,
          "FTP",
          Convert.convert(
            SCR.Execute(path(".target.bash_output"), ftp_command),
            :from => "any",
            :to   => "map <string, any>"
          )
        )
      else
        Builtins.y2milestone("Skipping FTP Proxy test, no proxy used.")
        Ops.set(
          ret,
          "FTP",
          { "exit" => 0, "stderr" => "", "stdout" => "", "tested" => false }
        )
      end
      Builtins.y2milestone("Done.")

      deep_copy(ret)
    end

    # Dump the Routing settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      settings = {
        "enabled"        => @enabled,
        "http_proxy"     => @http,
        "https_proxy"    => @https,
        "ftp_proxy"      => @ftp,
        "no_proxy"       => @no,
        "proxy_user"     => @user,
        "proxy_password" => @pass
      }
      deep_copy(settings)
    end

    # Create proxy summary
    # @return summary text
    def Summary
      ret = []

      # Summary text
      if !@enabled
        ret = [Summary.Device(_("Proxy is disabled."), "")]
      else
        # Summary text
        ret = [
          Summary.Device(
            _("Proxy is enabled."),
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    "",
                    # Summary text
                    @http != "" ?
                      Ops.add(
                        Builtins.sformat(_("HTTP Proxy: %1"), @http),
                        "<br>"
                      ) :
                      ""
                  ),
                  # Summary text
                  @https != "" ?
                    Ops.add(
                      Builtins.sformat(_("HTTPS Proxy: %1"), @https),
                      "<br>"
                    ) :
                    ""
                ),
                # Summary text
                @ftp != "" ?
                  Ops.add(Builtins.sformat(_("FTP Proxy: %1"), @ftp), "<br>") :
                  ""
              ),
              ""
            )
          )
        ] 

        # Summary text * /
        # Summary::Device(sformat(_("No Proxy Domains: %1"), no) + "\n<br>" +
        # "<p>" + ( user == "" ?
        # 		/* Summary text * /
        # 		_("Proxy user name is not set.") :
        # 		/* Summary text * /
        # 		sformat(_("Proxy User Name: %1"), user)) +
        # "<br>" + ( pass == "" ?
        # 		/* Summary text * /
        # 		_("Proxy password is not set.") :
        # 		/* Summary text * /
        # 		_("Proxy password is set.")) ];
      end

      Summary.DevicesList(ret)
    end

    # Function which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end
    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Function returns an environment usable for curl.  The proxy user/password
    # are read from /root/.curlrc.
    def GetEnvironment
      return {} if !@enabled

      Read() if !@modified

      {
        "http_proxy"  => @http,
        "HTTPS_PROXY" => @https,
        "FTP_PROXY"   => @ftp,
        "NO_PROXY"    => @no
      }
    end

    publish :variable => :proposal_valid, :type => "boolean"
    publish :variable => :write_only, :type => "boolean"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :enabled, :type => "boolean"
    publish :variable => :http, :type => "string"
    publish :variable => :https, :type => "string"
    publish :variable => :ftp, :type => "string"
    publish :variable => :no, :type => "string"
    publish :variable => :user, :type => "string"
    publish :variable => :pass, :type => "string"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :RunTestProxy, :type => "map <string, map <string, any>> (string, string, string, string, string)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetEnvironment, :type => "map <string, string> ()"
  end

  Proxy = ProxyClass.new
  Proxy.main
end
