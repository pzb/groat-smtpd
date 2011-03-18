# vim: set sw=2 sts=2 ts=2 et syntax=ruby: #
=begin license
  Copyright 2011 Novell, Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Author(s):
    Peter Bowen <pzbowen@gmail.com> Ottawa, Ontario, Canada
=end

module Groat
module SMTPD
  module Extensions
    module Authentication
      module Login
        def self.included mod
          puts "Included Non-standard LOGIN Authentication Mechanism"
          raise SMTPExtensionError.new("LOGIN auth mechanism requires AUTH") unless mod.ehlo_keyword_known? :auth
          mod.auth_mechanism :login, :auth_mech_login, :secure?
          super
        end

        def validate_auth_login(user, pass)
          response_auth_temp_fail
        end

        def auth_mech_login(arg)
          response_bad_command_parameter(:message => "Encrypted session required", 
                                         :terminate => false) unless secure?
          check_command_group
          unless arg.nil?
            response_syntax_error(:message => "LOGIN does not allow initial response")
          end
          # Outlook requires "Username:" (vs the draft which says "User Name")
          toclient "334 " + Base64.encode64("Username:").strip + "\r\n"
          r = fromclient.chomp
          if r.eql? '*'
            response_syntax_error(:message => "Authentication Quit")
          end
          if r !~ BASE64_VALID
            response_syntax_error(:message => "Bad response")
          end
          username = Base64.decode64(r) 
          # Outlook requires "Password:" (vs the draft which says "Password")
          toclient "334 " + Base64.encode64("Password:").strip + "\r\n"
          r = fromclient.chomp
          if r.eql? '*'
            response_syntax_error(:message => "Authentication Quit")
          end
          if r !~ BASE64_VALID
            response_syntax_error(:message => "Bad response")
          end
          password = Base64.decode64(r) 
          res = validate_auth_login(username, password)
          if res
            @authenticated = true
            response_auth_ok
          end
        end
      end
    end
  end
end
end
