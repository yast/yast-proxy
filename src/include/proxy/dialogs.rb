# encoding: utf-8

# File:	include/proxy/dialogs.ycp
# Package:	Proxy configuration
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  module ProxyDialogsInclude
    def initialize_proxy_dialogs(include_target)
      Yast.import "UI"

      textdomain "proxy"

      Yast.import "Address"
      Yast.import "Hostname"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Netmask"
      Yast.import "Popup"
      Yast.import "Proxy"
      Yast.import "String"
      Yast.import "URL"
      Yast.import "Wizard"

      @enabled = false
      @http = ""
      @https = ""
      @ftp = ""
      @no = ""
      @user = ""
      @pass = ""
      @same_proxy = false
      # String to pre-filled into the proxy server field
      @prefill = "http://"

      # Known return codes - good proxy response
      @return_codes_good = [
        "200", # OK
        "201", # Created
        "202", # Accepted
        "203", # Non-Authorative Information
        "204", # No Content
        "205", # Reset Content
        "206", # Partial Content
        "300", # Multiple Choices
        "301", # Moved Permanently
        "302", # Moved Temporarily
        "303", # See Other
        "304", # Not Modified
        "305"
      ] # Use Proxy

      # Known return codes - bad proxy response
      @return_codes_bad = [
        # Proxy Errors
        "400", # Bad Request
        "401", # Authorization Required
        "402", # Payment Required (not used yet)
        "403", # Forbidden
        "404", # Not Found
        "405", # Method Not Allowed
        "406", # Not Acceptable (encoding)
        "407", # Proxy Authentication Required
        "408", # Request Timed Out
        "409", # Conflicting Request
        "410", # Gone
        "411", # Content Length Required
        "412", # Precondition Failed
        "413", # Request Entity Too Long
        "414", # Request URI Too Long
        "415", # Unsupported Media Type
        # Server Errors
        "500", # Internal Server Error
        "501", # Not Implemented
        "502", # Bad Gateway
        "503", # Service Unavailable
        "504", # Gateway Timeout
        "505"
      ] # HTTP Version Not Supported
    end

    # from OnlineUpdateDialogs.ycp
    # Function opens the generic error dialog including the
    # message with the [Details >>] button. It handles pressing
    # the button itself.
    #
    # @param string message with the short error message
    # @param string details with all of the error details

    def modified
      !(Proxy.http == @http && Proxy.ftp == @ftp && Proxy.no == @no &&
        Proxy.https == @https &&
        Proxy.user == @user &&
        Proxy.pass == @pass &&
        Proxy.enabled == @enabled)
    end

    def ErrorPopupGeneric(message, details)
      # Informative label
      details = _("No details available.") if Builtins.size(details) == 0

      # A push button
      detailsStringOn = _("&Details <" + "<") # avoid confusing Emacs
      # A push button
      detailsStringOff = _("&Details >>")

      detailsButton = PushButton(Id(:details), detailsStringOff)

      heading = Label.ErrorMsg

      buttons = HBox(detailsButton, PushButton(Id(:ok), Label.OKButton))

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HBox(HSpacing(0.5), Left(Heading(heading))),
          VSpacing(0.2),
          Left(Label(message)),
          ReplacePoint(Id(:rp), Empty()),
          buttons
        )
      )

      ret = nil
      showDetails = false

      while ret != :ok
        ret = UI.UserInput

        if ret == :details
          if showDetails
            UI.ReplaceWidget(Id(:rp), Empty())
            UI.ChangeWidget(Id(:details), :Label, detailsStringOff)
          else
            UI.ReplaceWidget(
              Id(:rp),
              HBox(
                HSpacing(0.5),
                HWeight(1, RichText(Opt(:plainText), details)),
                HSpacing(0.5)
              )
            )
            UI.ChangeWidget(Id(:details), :Label, detailsStringOn)
          end
          showDetails = !showDetails
        end
      end

      UI.CloseDialog

      nil
    end

    # Function checks the proxy-return code and displays a pop-up
    # if the code means an error.
    #
    # @param [String] test_type HTTP, HTTPS or FTP
    # @param [String] proxy_ret_stderr such as "HTTP/1.0 403 Forbidden"
    # @return [Boolean] true if the proxy response is a good one
    def TestProxyReturnCode(test_type, proxy_ret_stderr)
      proxy_retcode = ""
      # getting the return code string from the stderr
      Builtins.foreach(Builtins.splitstring(proxy_ret_stderr, "\r?\n")) do |proxy_stderr|
        if Builtins.regexpmatch(proxy_stderr, "HTTP/[0-9.]+ [0-9]+")
          proxy_retcode = Builtins.regexpsub(proxy_stderr, ".*(HTTP.*)", "\\1")
        end
      end

      Builtins.y2milestone("Proxy %1 test: %2", test_type, proxy_retcode)

      # The default error code, replaced with the current error code got from proxy if any code found
      retcode = _("Unknown Error Code")
      Builtins.foreach(Builtins.splitstring(proxy_retcode, " ")) do |ret_code_part|
        if Builtins.regexpmatch(ret_code_part, "^[0-9]+$") &&
            Ops.greater_or_equal(Builtins.size(ret_code_part), 3)
          retcode = ret_code_part
        end
      end

      # known good return code
      if Builtins.contains(@return_codes_good, retcode)
        return true 
        # known bad return code
      elsif Builtins.contains(@return_codes_bad, retcode)
        # Error message,
        #	%1 is a string "HTTP", "HTTPS" or "FTP"
        #	%2 is an error string such as "HTTP/1.0 403 Forbidden"
        ErrorPopupGeneric(
          Builtins.sformat(
            _(
              "An error occurred during the %1 proxy test.\nProxy return code: %2.\n"
            ),
            test_type,
            proxy_retcode
          ),
          proxy_ret_stderr
        )
        return false
      else
        # Unknown return code,
        #	%1 is the string HTTP, "HTTPS" or FTP,
        #	%2 is an error string such as "HTTP/1.0 403 Forbidden"
        ErrorPopupGeneric(
          Builtins.sformat(
            _(
              "An unknown error occurred during the %1 proxy test.\nProxy return code: %2.\n"
            ),
            test_type,
            proxy_retcode
          ),
          proxy_ret_stderr
        )
      end

      nil
    end

    # Function test the current HTTP and FTP proxy settings.
    # It currently ignores the "No Proxy" value.
    #
    # @return [Boolean] true if successful
    def TestProxySettings
      if @enabled
        UI.OpenDialog(
          # An informative popup label diring the proxy testings
          Left(Label(_("Testing the current proxy settings...")))
        )
        ret = Proxy.RunTestProxy(@http, @https, @ftp, @user, @pass)
        UI.CloseDialog

        # curl error
        if Ops.get_boolean(ret, ["HTTP", "tested"], true) == true
          if Ops.get_integer(ret, ["HTTP", "exit"], 1) != 0
            # TRANSLATORS: Error popup message
            ErrorPopupGeneric(
              _("An error occurred during the HTTP proxy test."),
              Ops.get_string(ret, ["HTTP", "stderr"], "")
            )
            UI.SetFocus(Id(:http))
            return false
          else
            # curl works - proxy error
            if !TestProxyReturnCode(
                "HTTP",
                Ops.get_string(ret, ["HTTP", "stderr"], "")
              )
              UI.SetFocus(Id(:http))
              return false
            end
          end
        end

        if Ops.get_boolean(ret, ["HTTPS", "tested"], true) == true
          # curl error
          if Ops.get_integer(ret, ["HTTPS", "exit"], 1) != 0
            # TRANSLATORS: Error popup message
            ErrorPopupGeneric(
              _("An error occurred during the HTTPS proxy test."),
              Ops.get_string(ret, ["HTTPS", "stderr"], "")
            )
            UI.SetFocus(Id(:https))
            return false
          else
            # curl works - proxy error
            if !TestProxyReturnCode(
                "HTTPS",
                Ops.get_string(ret, ["HTTPS", "stderr"], "")
              )
              UI.SetFocus(Id(:https))
              return false
            end
          end
        end

        if Ops.get_boolean(ret, ["FTP", "tested"], true) == true
          # curl error
          if Ops.get_integer(ret, ["FTP", "exit"], 1) != 0
            # TRANSLATORS: Error popup message
            ErrorPopupGeneric(
              _("An error occurred during the FTP proxy test."),
              Ops.get_string(ret, ["FTP", "stderr"], "")
            )
            UI.SetFocus(Id(:ftp))
            return false
          else
            # curl works - proxy error
            if !TestProxyReturnCode(
                "FTP",
                Ops.get_string(ret, ["FTP", "stderr"], "")
              )
              UI.SetFocus(Id(:ftp))
              return false
            end
          end
        end

        # Popup message
        Popup.Message(_("Proxy settings work correctly."))
      else
        # Actually it doesn't make sense to test the proxy settings when proxy is off
        return true
      end

      nil
    end

    def InitSameProxy
      #We have the same (non-empty) proxy URL for all protocols
      if @http != @prefill && @http == @https && @https == @ftp
        UI.ChangeWidget(Id(:same_proxy), :Value, true)
        UI.ChangeWidget(Id(:https), :Enabled, false)
        UI.ChangeWidget(Id(:https), :Value, @prefill)
        UI.ChangeWidget(Id(:ftp), :Enabled, false)
        UI.ChangeWidget(Id(:ftp), :Value, @prefill)
      end

      nil
    end

    def QueryWidgets
      @same_proxy = Convert.to_boolean(UI.QueryWidget(Id(:same_proxy), :Value))
      @http = Convert.to_string(UI.QueryWidget(Id(:http), :Value))
      if @same_proxy
        @https = @http
        @ftp = @http
      else
        @https = Convert.to_string(UI.QueryWidget(Id(:https), :Value))
        @ftp = Convert.to_string(UI.QueryWidget(Id(:ftp), :Value))
      end

      @user = Convert.to_string(UI.QueryWidget(Id(:user), :Value))
      @pass = Convert.to_string(UI.QueryWidget(Id(:pass), :Value))
      @enabled = Convert.to_boolean(UI.QueryWidget(Id(:enabled), :Value))

      @no = Convert.to_string(UI.QueryWidget(Id(:no), :Value))

      nil
    end

    def ValidateNoProxyDomains(no_proxies)
      proxy_list = Builtins.splitstring(no_proxies, ",")
      validate = true
      hostname = ""
      netmask = ""

      Builtins.foreach(proxy_list) do |one_proxy|
        one_proxy = String.CutBlanks(one_proxy)
        # IP/netmask
        if Builtins.findfirstof(one_proxy, "/") != nil
          tmp = Builtins.splitstring(one_proxy, "/")
          hostname = Ops.get(tmp, 0, "")
          netmask = Ops.get(tmp, 1, "")

          validate = false if !Netmask.Check(netmask)
        else
          hostname = one_proxy
          # .domain.name case
          if Builtins.findfirstof(hostname, ".") == 0
            hostname = Builtins.substring(hostname, 1)
          end
        end
        Builtins.y2milestone("hostname %1, netmask %2", hostname, netmask)
        validate = false if !Address.Check(hostname)
      end

      validate
    end

    def UrlContainPassword(url)
      ret = URL.Parse(url)

      Ops.greater_than(Builtins.size(Ops.get_string(ret, "pass", "")), 0)
    end

    # If modified, ask for confirmation
    # @return true if abort is confirmed
    def ReallyAbortCond
      !modified || Popup.ReallyAbort(true)
    end

    # Proxy dialog
    # @param [Boolean] standalone true if not run from another ycp client
    # @return dialog result
    def ProxyMainDialog(standalone)
      @enabled = Proxy.enabled
      @http = Proxy.http
      @https = Proxy.https
      @ftp = Proxy.ftp
      @no = Proxy.no
      @user = Proxy.user
      @pass = Proxy.pass

      @http = @prefill if @http == ""
      @https = @prefill if @https == ""
      @ftp = @prefill if @ftp == ""

      # Proxy dialog caption
      caption = _("Proxy Configuration")

      # Proxy dialog help 1/8
      help = Ops.add(
        Ops.add(
          Ops.add(
            _(
              "<p>Configure your Internet proxy (caching) settings here.</p>\n" +
                "<p><b>Note:</b> It is generally recommended to relogin for the settings to take effect, \n" +
                "however in some cases the application may pick up new settings immediately. Please check \n" +
                "what your application (web browser, ftp client,...) supports. </p>"
            ) +
              # Proxy dialog help 2/8
              _(
                "<p><b>HTTP Proxy URL</b> is the name of the proxy server for your access\nto the World Wide Web (WWW).</p>\n"
              ) +
              # Proxy dialog help 3/8
              _(
                "<p><b>HTTPS Proxy URL</b> is the name of the proxy server for your secured access\nto the World Wide Web (WWW).</p>\n"
              ) +
              # Proxy dialog help 3.5/8
              _("<p>Example: <i>http://proxy.example.com:3128/</i></p>") +
              # Proxy dialog help 4/8
              _(
                "<p><b>FTP Proxy URL</b> is the name of the proxy server for your access\nto the file transfer services (FTP).</p>"
              ) +
              # Proxy dialog help 5/8
              _(
                "<p>If you check <b>Use the Same Proxy for All Protocols</b>, it is\n" +
                  "enough to fill in the HTTP proxy URL. It will be used for all protocols\n" +
                  "(HTTP, HTTPS and FTP).\n"
              ),
            # Proxy dialog help 6/8
            Builtins.sformat(
              _(
                "<p><b>No Proxy Domains</b> is a comma-separated list of domains\n" +
                  "for which the requests should be made directly without caching,\n" +
                  "for example, <i>%1</i>.</p>\n"
              ),
              "localhost, .intranet.example.com, www.example.com"
            )
          ),
          # Proxy dialog help 7/8
          _(
            "<p>If you are using a proxy server with authorization, enter\n" +
              "the <b>Proxy User Name</b> and <b>Proxy Password</b>. A valid username\n" +
              "consists of printable ASCII characters only (except for quotation marks).</p>\n"
          )
        ),
        # Proxy dialog help 8/8
        !Mode.installation ?
          _(
            "<p>Press <b>Test Proxy Settings</b> to test\nthe current configuration for HTTP, HTTPS, and FTP proxy.</p> \n"
          ) :
          ""
      )

      display_info = UI.GetDisplayInfo
      textmode = Ops.get_boolean(display_info, "TextMode", false)

      s = textmode ? 0.2 : 0.5

      # Proxy dialog contents
      contents = HBox(
        HSpacing(5),
        VBox(
          # CheckBox entry label
          Left(
            CheckBox(Id(:enabled), Opt(:notify), _("&Enable Proxy"), @enabled)
          ),
          VSpacing(s),
          # Frame label
          Frame(
            Id(:frame1),
            _("Proxy Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(0.2),
                # Text entry label
                TextEntry(Id(:http), _("&HTTP Proxy URL"), @http),
                VSpacing(0.2),
                TextEntry(Id(:https), _("HTTP&S Proxy URL"), @https),
                VSpacing(0.2),
                # Text entry label
                TextEntry(Id(:ftp), _("F&TP Proxy URL"), @ftp),
                VSpacing(0.2),
                Left(
                  CheckBox(
                    Id(:same_proxy),
                    Opt(:notify),
                    _("Us&e the Same Proxy for All Protocols")
                  )
                ),
                # Text entry label
                # domains without proxying
                TextEntry(Id(:no), _("No Proxy &Domains"), @no),
                textmode ? Empty() : VSpacing(0.4)
              ),
              HSpacing(2)
            )
          ),
          VSpacing(s),
          Frame(
            Id(:frame2),
            _("Proxy Authentication"),
            HBox(
              HSpacing(2),
              VBox(
                # Text entry label
                HBox(
                  InputField(
                    Id(:user),
                    Opt(:hstretch),
                    _("Proxy &User Name"),
                    @user
                  ),
                  HSpacing(0.5),
                  # Password entry label
                  Password(
                    Id(:pass),
                    Opt(:hstretch),
                    _("Proxy &Password"),
                    @pass
                  ),
                  textmode ? Empty() : VSpacing(0.4)
                )
              ),
              HSpacing(2)
            )
          ),
          VSpacing(s),
          # Test Proxy Settings - push button
          !Mode.installation ?
            PushButton(Id("test_proxy"), _("Test Pr&oxy Settings")) :
            Empty()
        ),
        HSpacing(5)
      )

      #    if(standalone == true)
      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.FinishButton
      )
      Wizard.SetNextButton(:next, Label.OKButton)
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.HideBackButton
      #     else
      # 	Wizard::SetContentsButtons(caption, contents, help,
      # 		Label::BackButton(), Label::OKButton());

      # #103841, relaxed. now avoiding only quotes
      # #337048 allow using space as well
      # was CAlnum() + ".:_-/\\"
      _ValidCharsUsername = Ops.add(
        Builtins.deletechars(String.CGraph, "'\""),
        " "
      )
      UI.ChangeWidget(Id(:http), :ValidChars, URL.ValidChars)
      UI.ChangeWidget(Id(:https), :ValidChars, URL.ValidChars)
      UI.ChangeWidget(Id(:ftp), :ValidChars, URL.ValidChars)
      # '/' character for subnets definition - #490661
      UI.ChangeWidget(
        Id(:no),
        :ValidChars,
        Ops.add(Hostname.ValidCharsDomain, " ,/")
      )
      UI.ChangeWidget(Id(:user), :ValidChars, _ValidCharsUsername)
      UI.ChangeWidget(Id(:frame1), :Enabled, @enabled)
      UI.ChangeWidget(Id(:frame2), :Enabled, @enabled)
      if !Mode.installation
        UI.ChangeWidget(Id("test_proxy"), :Enabled, @enabled)
      end
      InitSameProxy()

      if @enabled == true
        UI.SetFocus(Id(:http))
      else
        UI.SetFocus(Id(:enabled))
      end

      ret = nil
      while true
        ret = UI.UserInput
        QueryWidgets()

        # abort?
        if ret == :abort || ret == :cancel || ret == :back
          if ReallyAbortCond()
            break
          else
            next
          end
        end
        if ret == :enabled
          UI.ChangeWidget(Id(:frame1), :Enabled, @enabled)
          UI.ChangeWidget(Id(:frame2), :Enabled, @enabled)
          UI.ChangeWidget(Id("test_proxy"), :Enabled, @enabled)
          InitSameProxy()
          next
        elsif ret == :same_proxy
          UI.ChangeWidget(Id(:https), :Value, @prefill)
          UI.ChangeWidget(Id(:ftp), :Value, @prefill)
          UI.ChangeWidget(Id(:https), :Enabled, !@same_proxy)
          UI.ChangeWidget(Id(:ftp), :Enabled, !@same_proxy)
          next
        # next
        elsif ret == :next || ret == "test_proxy"
          @http = "" if @http == @prefill
          @https = "" if @https == @prefill
          @ftp = "" if @ftp == @prefill

          break if @enabled == false
          if @http == "" && @https == "" && @ftp == ""
            # Popup error text - http, https and ftp proxy URLs are blank
            if !Popup.ContinueCancel(
                _(
                  "Proxy is enabled, but no proxy URL has been specified.\nReally use these settings?"
                )
              )
              next
            end
          else
            password_inside = UrlContainPassword(@http) ||
              UrlContainPassword(@https) ||
              UrlContainPassword(@ftp)

            if password_inside && ret != "test_proxy"
              if !Popup.ContinueCancel(
                  _(
                    "Security warning:\n" +
                      "Username and password will be stored unencrypted\n" +
                      "in a worldwide readable plaintext file.\n" +
                      "Really use these settings?"
                  )
                )
                next
              end
            end
          end
          # check_*
          if @user == "" && @pass != ""
            # Popup::Error text
            Popup.Error(
              _("You cannot enter a password and leave the user name empty.")
            )
            UI.SetFocus(Id(:user))
            next
          end
          if @http != "" && @http != @prefill
            if !URL.Check(@http)
              # Popup::Error text
              Popup.Error(_("HTTP proxy URL is invalid."))
              UI.SetFocus(Id(:http))
              next
            end
            urlmap = URL.Parse(@http)
            if Ops.get_string(urlmap, "scheme", "") == ""
              # Popup::Error text
              Popup.Error(
                _("HTTP proxy URL must contain a scheme specification (http).")
              )
              UI.SetFocus(Id(:http))
              next
            end
          end
          if @https != "" && @https != @prefill
            if !URL.Check(@https)
              # Popup::Error text
              Popup.Error(_("The HTTPS proxy URL is invalid."))
              UI.SetFocus(Id(:https))
              next
            end
            urlmap = URL.Parse(@https)
            if Ops.get_string(urlmap, "scheme", "") == ""
              # Popup::Error text
              Popup.Error(
                _(
                  "The HTTPS proxy URL must contain a scheme specification (http)."
                )
              )
              UI.SetFocus(Id(:https))
              next
            end
          end
          if @ftp != "" && @ftp != @prefill
            if !URL.Check(@ftp)
              # Popup::Error text
              Popup.Error(_("FTP proxy URL is invalid."))
              UI.SetFocus(Id(:ftp))
              next
            end
            urlmap = URL.Parse(@ftp)
            if Ops.get_string(urlmap, "scheme", "") == ""
              # Popup::Error text
              Popup.Error(
                _("FTP proxy URL must contain a scheme specification (http).")
              )
              UI.SetFocus(Id(:ftp))
              next
            end
          end
          if @no != "" && @no != nil
            if !ValidateNoProxyDomains(@no)
              #Translators: no proxy domain is a domain that can be accessed without proxy
              Popup.Error(
                _(
                  "One or more no proxy domains are invalid. \n" +
                    "Check if all domains match one of the following:\n" +
                    "* IP address\n" +
                    "* IP address/netmask\n" +
                    "* Fully qualified hostname\n" +
                    "* Domain name prefixed by '.'"
                )
              )
              UI.SetFocus(Id(:no))
              next
            end
          end

          if ret == :next
            break
          elsif ret == "test_proxy"
            TestProxySettings()
          end
        # back
        elsif ret == :back
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      if ret == :next
        if !modified
          Builtins.y2debug("not modified")
          return deep_copy(ret)
        end


        Proxy.enabled = @enabled
        if @enabled
          Proxy.http = @http
          Proxy.https = @https
          Proxy.ftp = @ftp
          Proxy.no = @no
          Proxy.user = @user
          Proxy.pass = @pass
        end

        Proxy.SetModified
      end

      deep_copy(ret)
    end
  end
end
