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

require 'base64'

module Groat
module SMTPD
  module Extensions
    module Authentication
      module ClassMethods
        def auth_mechanism(name, method, condition = nil)
          sym = name.to_s.upcase.intern
          auth_mechanisms[sym] = {} unless auth_mechanisms.has_key? sym
          auth_mechanisms[sym] = {:method => method, :condition => condition}
        end
      end 

      def reset_connection
        @authenticated = false
        super
      end

      def reset_buffers
        @mail_auth = nil
        super
      end

      def authenticated?
        @authenticated
      end

      def auth_params
        list = []
        self.class.auth_mechanisms.each do |k, v|
          valid = false

          if v[:condition].nil?
            valid = true
          else
            valid = send v[:condition]
          end

          list << k if valid
        end
        list
      end

      def show_auth_keyword?
        not authenticated?
      end

      def response_auth_ok(args = {})
        defaults = {:code => 235, :message => "Authentication Succeeded"}
        reply defaults.merge(args)
      end

      def response_auth_temp_fail(args = {})
        defaults = {:code => 454, :message => "Temporary Failure"}
        reply defaults.merge(args)
      end

      def response_auth_required(args = {})
        defaults = {:code => 530, :message => "Authentication required"}
        reply defaults.merge(args)
      end

      def response_auth_failure(args = {})
        defaults = {:code => 535, :message => "Credentials Invalid"}
        reply defaults.merge(args)
      end

      def self.included mod
        puts "Included RFC 4954: Authentication"
        mod.extend ClassMethods
        mod.inheritable_attr(:auth_mechanisms)
        mod.auth_mechanisms = {}
        mod.ehlo_keyword :auth, :auth_params, :show_auth_keyword?
        mod.verb :auth, :smtp_verb_auth
        mod.mail_param :auth, :mail_param_auth
        mod.auth_mechanism :plain, :auth_mech_plain, :secure?
        super
      end


      def validate_auth_plain(cid, zid, pass)
        response_auth_temp_fail
      end

      # RFC 4616
      def auth_mech_plain(arg)
        response_bad_command_parameter(:message => "Encrypted session required", 
                                       :terminate => false) unless secure?
        pipelinable unless arg.nil?
        check_command_group
        if arg.nil?
          toclient "334 \r\n"
          arg = fromclient
          arg.chomp!
        end
        if arg.eql? '*'
          response_syntax_error(:message => "Authentication Quit")
        end
        if arg !~ BASE64_VALID
          response_syntax_error(:message => "Bad response")
        end
        decoded = Base64.decode64(arg) 
        cid, zid, pass = decoded.split("\000")
        res = validate_auth_plain(cid, zid, pass)
        if res
          @authenticated = true
          response_auth_ok
        end
      end

      def auth_mechanism_method(name)
        mech = self.class.auth_mechanisms[name]
        unless mech.nil?
          self.class.auth_mechanisms[name][:method]
        end
      end

      BASE64_VALID = /\A[A-Z0-9\/+]*=*\Z/i

      def smtp_verb_auth(args)
        response_bad_syntax unless esmtp?
        response_bad_sequence(:message => 'Already authenticated', 
                              :terminate=> false) if authenticated?
        response_bad_sequence if in_mail_transaction? 
        mechanism, *initial_response = args.split(" ")
        response_bad_command_parameter if mechanism.nil?
        response_bad_command_parameter if initial_response.count > 1
        if initial_response.count == 1 and initial_response[0] !~ BASE64_VALID
          response_bad_command_parameter
        end
        mechanism = mechanism.to_s.upcase.intern
        response_bad_command_parameter if auth_mechanism_method(mechanism).nil?
        send auth_mechanism_method(mechanism), initial_response[0]
      end

      def mail_param_auth(param)
        @mail_auth = from_xtext param
        puts "MAIL AUTH=#{@mail_auth}"
      end
    end
  end
end
end
