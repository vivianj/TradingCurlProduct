require 'mail'
require 'net/imap'
require 'nokogiri'

def getOrderId(content, subject)
    subject_re = /.*?order\s*#(\d+).*/
    storeId_re = /.*?store\s*(\d+).*?/
    transId_re = /.*?trans.*?(\d+).*?/
    dateId_re = /.*?date\/time.*?(\d{4}-\d{2}-\d{2}).*/
    orderId = ''

    if result = subject_re.match(subject)
       orderId = result.captures[0]
       puts "OrderId : #{orderId}"
       return orderId
       
    else 
      content.each_line do |line|
         line = line.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :replace => '?')
         #line = line.force_encoding('UTF-8') 
         line = line.gsub("/[*|>]|=09/","").downcase<<' '
         #line = line.downcase
         
         if line.empty? || line.nil?
            next
         end
        
        #puts line
         if result = storeId_re.match(line)
            orderId << result.captures[0]
            next
         end
         
         if result = transId_re.match(line)
            orderId << result.captures[0]
         end

         if result = dateId_re.match(line)
            orderId << result.captures[0].gsub('-','')
            puts "OrderId : #{orderId}"
            return orderId 
         end
       
      end 
               
  end
end
def getEmailContent(message)
    content = ''
    if message.multipart?
        puts "Email : #{message.subject} is multipart type"

       message.parts.each do |part|
         if part.content_type.include? 'plain'
            content+=part.decode_body.force_encoding('UTF-8') 
         elsif part.content_type.include? 'html'
            content+=Nokogiri::HTML(part.decode_body).text 
         elsif part.multipart?
            content += getEmailContent(part) 
        end
      end
   elsif message.content_type.include? 'plain' 
         puts "Email : #{message.subject} is text type"
         content+=message.decode_body
   elsif message.content_type.include? 'html'
         puts "Email : #{message.subject} is html"
         content+=Nokogiri::HTML(message.decode_body).text
   end

   return content 
end

def readEmail 
    imap = Net::IMAP.new('imap.gmail.com',993,true)
    imap.login("kangyihong001@gmail.com", "831218xx")
    imap.select("order rename")
    destFolder = 'renamedEmails'

    mailIds = imap.search(['ALL'])
    mailIds.each do |id|
        msg = imap.fetch(id,'BODY[]')[0].attr['BODY[]']
        mail = Mail.read_from_string msg
        
        content = getEmailContent(mail)
        #puts content
        orderId = getOrderId(content, mail.subject)

        if not /.*?order\s*#\d+.*/.match(mail.subject.downcase) and not orderId.nil?
           newMail = Mail.new
           newMail = mail
           newMail.subject = mail.subject << " order # " << orderId
           imap.append(destFolder, newMail.to_s)
           puts "renamed email #{mail.subject}"
        else
            imap.copy(id, destFolder)
            puts "move the email #{mail.subject}"
        end

        imap.store(id, "+FLAGS",[:Deleted])
   end

   imap.logout()
   imap.disconnect() 
end

readEmail
