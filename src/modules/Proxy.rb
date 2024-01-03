require "yast"
require "shellwords"

module Yast
  # Configures FTP and HTTP proxies via sysconfig
  # and /root/.curlrc (for YOU)
  class ProxyClass < Module
    # @return [Boolean] Whether the configuration should be copied to the target system
    attr_accessor :to_target

    def main
      textdomain "proxy"

      Yast.import "Summary"
      Yast.import "Progress"
      Yast.import "Mode"
      Yast.import "Stage"
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
      @to_target = false
    end

    # domains that should not be proxied; reader
    # @return [String]
    def no_proxy_domains
      clean_up_no_proxy(@no)
    end

    # domains that should not be proxied; writer
    # @param value [String]
    def no_proxy_domains=(value)
      @no = clean_up_no_proxy(value)
    end

    # Compatibility:
    publish variable: :no, type: "string"

    # we need "publish :variable" but it defines an attr_accessor
    # so let's undefine it
    remove_method :no
    remove_method :"no="
    alias_method :no, :no_proxy_domains
    alias_method :"no=", :"no_proxy_domains="

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
      ret << " module " << modul if !modul.nil? && modul != ""
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
      @http = "" if @http.nil?
      @https = Convert.to_string(SCR.Read(path(".sysconfig.proxy.HTTPS_PROXY")))
      @https = "" if @https.nil?
      @ftp = Convert.to_string(SCR.Read(path(".sysconfig.proxy.FTP_PROXY")))
      @ftp = "" if @ftp.nil?
      self.no_proxy_domains = SCR.Read(path(".sysconfig.proxy.NO_PROXY")) || ""
      @enabled = Convert.to_string(
        SCR.Read(path(".sysconfig.proxy.PROXY_ENABLED"))
      ) == "yes"

      # Read /root/.curlrc
      if Ops.greater_than(SCR.Read(path(".target.size"), "/root/.curlrc"), 0)
        @user = Convert.to_string(
          SCR.Read(Builtins.add(path(".root.curlrc"), "--proxy-user"))
        )
      end

      @user = "" if @user.nil?

      if Builtins.issubstring(@user, ":")
        @pass = Builtins.regexpsub(@user, "^.*:(.*)$", "\\1")
        @user = Builtins.regexpsub(@user, "^(.*):.*$", "\\1")
      end

      @pass = "" if @pass.nil?
      if @user.nil?
        @user = ""
      elsif Builtins.regexpmatch(@user, "^.*\\\\.*$")
        @user = Builtins.regexpsub(@user, "^(.*)\\\\(.*)$", "\\1\\2")
      end

      true
    end

    def WriteSysconfig
      SCR.Write(path(".sysconfig.proxy.PROXY_ENABLED"), @enabled ? "yes" : "no")
      SCR.Write(path(".sysconfig.proxy.HTTP_PROXY"), @http)
      SCR.Write(path(".sysconfig.proxy.HTTPS_PROXY"), @https)
      SCR.Write(path(".sysconfig.proxy.FTP_PROXY"), @ftp)
      SCR.Write(path(".sysconfig.proxy.NO_PROXY"), no_proxy_domains)
      SCR.Write(path(".sysconfig.proxy"), nil)
    end

    # Escape backslash characters in .curlrc (bnc#331038)
    # see also http://curl.haxx.se/docs/manpage.html#-K for escaping rules
    def EscapeForCurlrc(s)
      return nil if s.nil?

      Builtins.mergestring(Builtins.splitstring(s, "\\"),
        "\\\\")
    end

    def WriteCurlrc
      proxyuser = nil
      if @user && !@user.empty?
        proxyuser = @user
        proxyuser << ":" << @pass if @pass && !@pass.empty?
      end

      options = {
        "--proxy-user" => proxyuser,
        # bnc#305163
        "--proxy"      => @http,
        # bsc#923788
        "--noproxy"    => no_proxy_domains
      }

      # proxy is used, write /root/.curlrc
      if @enabled
        write_comment = true

        options.each do |option, value|
          value = nil if value == ""

          SCR.Write(path(".root.curlrc") + option, EscapeForCurlrc(value))

          next unless !value.nil? && write_comment

          SCR.Write(path(".root.curlrc") + option + "comment",
            ChangedComment("proxy"))
          write_comment = false
        end
        # proxy is not used, remove proxy-related settings
      else
        options.each_key do |option|
          SCR.Write(path(".root.curlrc") + option, nil)
        end
      end

      SCR.Write(path(".root.curlrc"), nil)
    end

    # Write proxy settings and apply changes
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
      sl = (Progress.status == true) ? 500 : 0

      Progress.New(caption, " ", Builtins.size(steps), steps, [], "")

      Progress.NextStage
      Progress.Title(_("Updating proxy configuration..."))

      # Update /etc/sysconfig/proxy
      WriteSysconfig()

      WriteCurlrc()
      Builtins.sleep(sl)
      Progress.NextStage

      # user can't relogin in installation and update, do not show the msg then
      # (bnc#486037, bnc#543469)
      ProxyFinishPopup(true) if Mode.normal
      # By now the configuration written to the inst-sys should be copied always to the target
      # system, so it is set here in order to discharge others from establishing it. (bsc#1185016)
      @to_target = true if Stage.initial

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
      self.no_proxy_domains = Ops.get_string(settings, "no_proxy", "localhost")
      @user = Ops.get_string(settings, "proxy_user", "")
      @pass = Ops.get_string(settings, "proxy_password", "")

      @modified = true
      true
    end

    # Runs tests of the HTTP and FTP proxy
    #
    # @param [String] http_proxy  such as "http://cache.example.com:3128"
    # @param [String] https_proxy  such as "http://cache.example.com:3128"
    # @param [String] ftp_proxy  such as "http://cache.example.com:3128"
    # @param [String] proxy_user  such as "proxy-username"
    # @param [String] proxy_password  such as "proxy-password"
    #
    # @return [Hash <String, Hash{String => Object>}] with results of the test
    #
    # **Structure:**
    #
    #     return = $[
    #       "HTTP" : $[
    #         "exit" : _exit_code,
    #         "stdout" : _stdout,
    #         "stderr" : _stderr,
    #       ],
    #       "HTTPS" : $[
    #         "exit" : _exit_code,
    #         "stdout" : _stdout,
    #         "stderr" : _stderr,
    #       ],
    #       "FTP" : $[
    #         "exit" : _exit_code,
    #         "stdout" : _stdout,
    #         "stderr" : _stderr,
    #       ],
    #      ]
    def RunTestProxy(http_proxy, https_proxy, ftp_proxy, proxy_user, proxy_password)
      # /usr/bin/curl --verbose
      # --proxy http://server_name:port_number
      # --proxy-user user:password
      # --url http://www.suse.com or ftp://ftp.suse.com | suggested for HTTP or FTP test
      # --url https://www.suse.com --insecure
      ret = {}

      test_http = (http_proxy != "" && http_proxy != "http://")
      test_https = (https_proxy != "" && https_proxy != "http://")
      test_ftp = (ftp_proxy != "" && ftp_proxy != "http://")

      user_pass = ""
      if proxy_user != "" && (proxy_password != "")
        user_pass = (" --proxy-user #{proxy_user.shellescape}" +
          user_pass) << ":#{proxy_password.shellescape}"
      end

      # timeout for the connection
      timeout_sec = 90
      # %1 = http or ftp proxy, %2 = user:password if any, %3 = URL
      command = "/usr/bin/curl --verbose --proxy %1 %2 --connect-timeout %3 --url %4"
      http_command = Builtins.sformat(
        command,
        http_proxy.shellescape,
        user_pass,
        timeout_sec,
        "http://www.suse.com"
      )
      # adding option --insecure to accept the certificate without asking
      https_command = Builtins.sformat(
        command,
        https_proxy.shellescape,
        user_pass,
        timeout_sec,
        "https://www.suse.com --insecure"
      )
      ftp_command = Builtins.sformat(
        command,
        ftp_proxy.shellescape,
        user_pass,
        timeout_sec,
        "ftp://ftp.suse.com"
      )

      Builtins.y2milestone("Running HTTP_PROXY test...")
      if test_http
        Builtins.y2milestone("Testing HTTP proxy %1", http_proxy)
        Ops.set(
          ret,
          "HTTP",
          Convert.convert(
            SCR.Execute(path(".target.bash_output"), http_command),
            from: "any",
            to:   "map <string, any>"
          )
        )
      else
        Builtins.y2milestone("Skipping HTTP Proxy test, no proxy used.")
        Ops.set(
          ret,
          "HTTP",
          "exit" => 0, "stderr" => "", "stdout" => "", "tested" => false
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
            from: "any",
            to:   "map <string, any>"
          )
        )
      else
        Builtins.y2milestone("Skipping HTTPS Proxy test, no proxy used.")
        Ops.set(
          ret,
          "HTTPS",
          "exit" => 0, "stderr" => "", "stdout" => "", "tested" => false
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
            from: "any",
            to:   "map <string, any>"
          )
        )
      else
        Builtins.y2milestone("Skipping FTP Proxy test, no proxy used.")
        Ops.set(
          ret,
          "FTP",
          "exit" => 0, "stderr" => "", "stdout" => "", "tested" => false
        )
      end
      Builtins.y2milestone("Done.")

      deep_copy(ret)
    end

    # Dump the Routing settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      settings = if @enabled
        {
          "enabled"        => true,
          "http_proxy"     => @http,
          "https_proxy"    => @https,
          "ftp_proxy"      => @ftp,
          "no_proxy"       => no_proxy_domains,
          "proxy_user"     => @user,
          "proxy_password" => @pass
        }
      else
        { "enabled" => false }
      end
      deep_copy(settings)
    end

    # Create proxy summary
    # @return summary text
    def Summary
      # Summary text
      ret = if @enabled
        # Summary text
        [
          Summary.Device(
            _("Proxy is enabled."),
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    "",
                    # Summary text
                    if @http == ""
                      ""
                    else
                      Ops.add(
                        Builtins.sformat(_("HTTP Proxy: %1"), @http),
                        "<br>"
                      )
                    end
                  ),
                  # Summary text
                  if @https == ""
                    ""
                  else
                    Ops.add(
                      Builtins.sformat(_("HTTPS Proxy: %1"), @https),
                      "<br>"
                    )
                  end
                ),
                # Summary text
                if @ftp == ""
                  ""
                else
                  Ops.add(Builtins.sformat(_("FTP Proxy: %1"), @ftp), "<br>")
                end
              ),
              ""
            )
          )
        ]
      else
        [Summary.Device(_("Proxy is disabled."), "")]
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
        "NO_PROXY"    => no_proxy_domains
      }
    end

    publish variable: :proposal_valid, type: "boolean"
    publish variable: :write_only, type: "boolean"
    publish variable: :modified, type: "boolean"
    publish variable: :enabled, type: "boolean"
    publish variable: :http, type: "string"
    publish variable: :https, type: "string"
    publish variable: :ftp, type: "string"
    publish variable: :user, type: "string"
    publish variable: :pass, type: "string"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :RunTestProxy,
      type: "map <string, map <string, any>> (string, string, string, string, string)"
    publish function: :Export, type: "map ()"
    publish function: :Summary, type: "string ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :SetModified, type: "void ()"
    publish function: :GetEnvironment, type: "map <string, string> ()"

  private

    # Clean up the no_proxy value: not all clients ignore spaces (bsc#1089796)
    def clean_up_no_proxy(v)
      v.gsub(" ", "")
    end
  end

  Proxy = ProxyClass.new
  Proxy.main
end
