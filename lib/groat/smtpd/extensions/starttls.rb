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

require 'openssl'

module Groat
module SMTPD
  module Extensions
    module StartTLS
      def self.included mod
        puts "Included RFC 3207: STARTTLS"
        mod.ehlo_keyword :starttls, nil, :show_starttls_keyword?
        mod.verb :starttls, :smtp_verb_starttls
      end

      def reset_connection
        @secure = false
        super
      end

      def set_ssl_context(ctx)
        @sslctx = ctx
      end

      def show_starttls_keyword?
        not secure?
      end

      def secure?
        @secure
      end

      def smtp_verb_starttls(args)
        check_command_group
        response_syntax_error unless args.empty?
        response_bad_sequence unless esmtp?
        # § 4.2 "A client MUST NOT attempt to start a TLS session if a TLS
        # session is already active"
        response_bad_sequence if secure?
        toclient "220 Ready to start TLS\r\n"
        ssl = OpenSSL::SSL::SSLSocket.new(@s, @sslctx)
        ssl.accept
        @s = ssl
        # http://www.imc.org/ietf-smtp/mail-archive/msg05452.html
        reset_connection
        @secure = true
        true
      end
    end
  end
end
end
