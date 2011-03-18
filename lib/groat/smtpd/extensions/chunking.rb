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
    module Chunking
      def self.included mod
        puts "Included RFC 3030: CHUNKING"
        mod.ehlo_keyword :chunking
        mod.verb :bdat, :smtp_verb_bdat
      end

      # BDAT is unusual in that the sender just shoves data at us
      # We need to grab that data before we response so as not to
      # try to parse it as commands
      def smtp_verb_bdat(args)
        arglist = args.split(' ')
        # No size means nothing to do
        if arglist.count < 1
          response_syntax_error :message => "Chunk size must be specified"
        end
        # The chunk size must be numeric
        if arglist[0] !~ /\A[0-9]+\Z/
          response_syntax_error :message => "Bad chunk size"
        end
        # Basic sanity passed, we must grab the data
        data = getdata(arglist[0].to_i)
        return response_no_valid_rcpt if @rcptto.count < 1
        if arglist.count > 2
          response_syntax_error
        elsif arglist.count == 2 and arglist[1].upcase != "LAST"
          response_syntax_error :message => "Bad end marker"
        end
        response_ok
      end
    end
  end
end
end
