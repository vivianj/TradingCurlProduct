require 'logger'

module Log
   class << self
     def logger
         @logger ||=Logger.new($stdout)
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
