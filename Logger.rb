require 'logger'

module EmailProcessor
 module Log
   class << self
     def logger
         @logger ||=Logger.new('readEmails.log', 'daily')

=begin         
         @logger.formatter = proc do | severity, datetime, progname, msg|
           "[#{datetime} - #{progname}] : #{severity} : #{msg}\n" 
         end
=end
     end

     def logger=(logger)
         @logger = logger
     end
   end

   def self.included(base)
       class << base
           def logger
               Log.logger
           end
       end
    end

    def logger
        self.class.logger
    end
 end
end
