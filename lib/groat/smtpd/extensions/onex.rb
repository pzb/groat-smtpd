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
    module Onex
      def self.included mod
        puts "Included non-RFC specified verb: ONEX"
        mod.ehlo_keyword :onex
        mod.verb :onex, :smtp_verb_onex
      end

      def smtp_verb_onex(args)
        response_ok
      end
    end
  end
end
end
