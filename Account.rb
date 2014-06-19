require 'mail'
require 'net/imap'
require 'net/smtp'

module EmailProcessor
	class Account
		 @username
		 @password
		 @imap
		 @smtp

		 def initialize(username, password)  
           # Instance variables  
           @username = username
           @password = passowrd
           
         end 

         def is_gmail?
             username.downcase.include? 'gmail'
         end

         def is_outlook?
         	 username.downcase.include? 'outlook'
         end

         def create_imap
         	begin 
             @imap = Net::IMAP.new('imap.gmail.com',993,true)
             @imap.login(@username, @password)
             
             rescue Net::IMAP::NoResponseError, Net::IMAP::ResponseError, Net::IMAP::ByeResponseError => ex
                    logger.error "Login user : #{@username}, Got Error message : " + ex.message
              end
         end

         def close_imap
         	 @imap.logout()
             @imap.disconnect() 
         end

         def create_smtp
         end

         def self.smtp
         	@smtp
         end

         def self.imap
         	@imap
         end

	end
end