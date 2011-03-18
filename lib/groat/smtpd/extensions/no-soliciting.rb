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
    module No_Soliciting
      def self.included mod
        puts "Included RFC 3865:NO_SOLICITING"
        mod.ehlo_keyword :"no-soliciting", :solicitation_keywords
        mod.mail_param :solicit, :smtp_verb_solicit
      end

      def solicitation_keywords
      end

      def mail_param_solicit(param)
        @mail_solicit = param
        puts "MAIL SOLICIT=#{@mail_solicit}"
      end
    end
  end
end
end
