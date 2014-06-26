require 'mail'
require 'net/imap'
require 'net/smtp'
require File.dirname(__FILE__) + '/Logger'

module EmailProcessor
 include Log

	class Account
		@@imap
              attr_reader :username
              attr_reader :password		 

        def initialize(username, password)  
           # Instance variables  
           @username = username
           @password = password
           
         end 
         
        class << self
           attr_accessor :usernam
        end

         def is_gmail?
             username.downcase.include? 'gmail'
         end

         def is_outlook?
         	 username.downcase.include? 'outlook'
         end

         def create_imap
         	begin 
             @@imap = Net::IMAP.new('imap.gmail.com',993,true)
             @@imap.login(@username, @password)
             
             rescue Net::IMAP::NoResponseError, Net::IMAP::ResponseError, Net::IMAP::ByeResponseError => ex
                    puts "Login user : #{@username}, Got Error message : " + ex.message
              end
             
              return @@imap
         end

         def close_imap
             @@imap.logout()
             @@imap.disconnect() 
         end

         def imap
             @@imap
         end

         def self.username
             @username
         end

         def self.password
             @password
         end

         def username=(value)
             @username = value
         end

         def password=(value)
             @password = value
         end

	end
end
