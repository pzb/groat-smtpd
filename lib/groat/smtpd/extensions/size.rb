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
    module Size
      def self.included mod
        puts "Included RFC 1870: Message Size Declaration"
        mod.ehlo_keyword :size, :max_mail_size
        mod.mail_param :size, :mail_param_size
        super
      end

       def mail_param_size(param)
        if (param !~ /\A[0-9]{1,20}\Z/)
          response_bad_parameter(:message => "Numeric size required")
        end
        @mail_size = param
        puts "MAIL SIZE=#{@mail_size}"
      end

      def max_mail_size
        "0"
      end
    end
  end
end
end
