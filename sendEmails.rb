require 'mail'
require 'net/smtp'
require File.dirname(__FILE__) + '/Logger'
require File.dirname(__FILE__) + '/Extractor'
require File.dirname(__FILE__) + '/Account'

# Author : Yuanyuan Jiang
# Date : 2014-06-19


module EmailProcessor

module_function

def sendErrorMessage(account, error, message)
	
    mail = Mail.new do
        from account.username
        subject =  "Go Error from uscaiigou system!"
    end
   
    if error.downcase.include? 'email not found'
       mail.to = message.from
       mail.body = 'Please add your email address : #{address} to the USCaigou system.'
     else 
      mail.body = "Hi Admin, Got error when processing order : #{error}"
      mail.to = 'kangyihong001@gmail.com'
    end

   sendEmail(mail, account, address)
end

def forwardEmail(message, newSubject,account, to_address)
     mail = Mail.new 
     mail['from'] = account.username
     mail[:to] = to_address 
     mail.subject = "Fwd:" + newSubject
           
      message.parts.each do |part|
         if part.content_type.include? 'html'
              mail.add_part(part)
          end
      end
      
      if mail.parts.length == 0
         logger.warn "Forward email : #{message.subject} body is empty"
      end     
          
      sendEmail(mail, account,to_address)
        
end

def sendEmail(mail, account, to_address)
	  smtp = Net::SMTP.new 'smtp.gmail.com', 587
      smtp.enable_starttls
    
      smtp.start('gmail.com', account.username, account.password, :plain) do |smtp|
       smtp.send_message mail.to_s, account.username, to_address 
      end	
end
end
