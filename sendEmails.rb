require 'mail'
require 'net/smtp'
require File.dirname(__FILE__) + '/Logger'
require File.dirname(__FILE__) + '/sendEmails'
require File.dirname(__FILE__) + '/extractEmails'
require File.dirname(__FILE__) + '/Account'

# Author : Yuanyuan Jiang
# Date : 2014-06-19


module EmailProcessor

module_function

def sendEmailToUser(account, error, address)
	mail = Mail.new do
        from account.username
        to address
        subject  error
	end

	if error.include? 'email not found'
		mail.body = 'Please add your email address : #{address} to the USCaigou system.'
	else error.include? ''
		mail.body = "Hi Admin, Got error when processing order : #{error}"
        address = 'kangyihong001@gmail.com'
        mail.to = address
        end

	sendEmail(mail, account, address)
end

def forwardEmail(message, account, to_address)
     mail = Mail.new 
     mail['from'] = account.username
     mail[:to] = to_address 
     mail.subject = "Fwd:" + message.subject
           
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
