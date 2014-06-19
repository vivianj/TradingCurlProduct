require 'mail'
require 'net/smtp'

# Author : Yuanyuan Jiang
# Date : 2014-06-19


module EmailProcessor
def sendEmailToUser(message, username, passowrd, error, to_address)
	mail = Mail.new do
        from username
        to to_address
        subject  error
	end

	if error.include? 'email not found'
		mail.body = 'Please add your email address : #{to_address} to the USCaigou system.'
	else
		mail.body = "Got error : #{error}"
    end
	sendEmail(mail, username, password, admin)
end

def forwardEmail(message, username, password, to_address)
     mail = Mail.new 
     mail['from'] = username
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
          
      sendEmail(mail, username, password,to_address)
        
end

def sendEmail(mail, username, password, to_address)
	  smtp = Net::SMTP.new 'smtp.gmail.com', 587
      smtp.enable_starttls
    
      smtp.start('gmail.com', username, password, :plain) do |smtp|
       smtp.send_message mail.to_s, username, to_address 
      end	
end
end
