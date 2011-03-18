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
    module Pipelining
      def reset_connection
        @pipelinable = false
        super
      end

      def self.included(klass)
        puts "Included RFC 2920: Pipelining"
        klass.after_all_verbs do |verb|
          puts "After #{verb}"
          @pipelinable = false
        end
        klass.before_verb :rset, :pipelinable
        klass.before_verb :mail, :pipelinable
        klass.before_verb :send, :pipelinable
        klass.before_verb :soml, :pipelinable
        klass.before_verb :saml, :pipelinable
        klass.before_verb :rcpt, :pipelinable
        super
      end

      def pipelinable
        @pipelinable = true
      end

      def check_command_group
        if not esmtp? or not @pipelinable
          if clientdata?
            response_bad_sequence
          end
        end
      end
    end
  end
end
end
