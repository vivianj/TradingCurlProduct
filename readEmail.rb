require 'rubygems'
require 'mail'
require 'net/imap'
require 'net/smtp'
require 'nokogiri'
require 'rest_client'
require 'json'
require 'date'
require_relative "Logger.rb"

include Log

def readEmails
    properties=loadPropertyFile('property.yml')
    
    username = properties['email']['username']
    password = properties['email']['password']
    mailbox = properties['email']['mailbox']
    responseUrl = properties['response']['url']
    
    if username.empty?
       logger.error "no email address provided for reading"
    elsif password.empty?
       logger.error "no password provided for reading email"
    elsif mailbox.empty?
       mailbox = "Inbox"
       logger.info "No mailbox is provided, using the default Inbox folder"
    elsif responseUrl.empty?
       logger.error "response Url is empty"
    end
    
    logger.info "Username :#{username}, Password :#{password}, Mailbox: #{mailbox}, responseUrl: #{responseUrl}"

    readEmail(username,password,mailbox,responseUrl)

end

def forwardEmail(message, username, password, to_address)
     newMail = Mail.new 
     newMail['from'] = username
     newMail[:to] = to_address 
     newMail.subject = "FWd:" + message.subject
           
      message.parts.each do |part|
         if part.content_type.include? 'html'
              newMail.add_part(part)
          end
      end
      
      if newMail.parts.length == 0
         logger.warn "Forward email : #{message.subject} body is empty"
      end     
          
      smtp = Net::SMTP.new 'smtp.gmail.com', 587
      smtp.enable_starttls
    
      smtp.start('gmail.com', username,password,:plain) do |smtp|
       smtp.send_message newMail.to_s, username, to_address 
      end
        
end

def loadPropertyFile(filePath)
    if File.exist?(filePath)
       logger.info "Loading the property file #{filePath}"
       properties = YAML.load_file(filePath)
       return properties
    else
     logger.error "The property file - #{filePath} is not exist"
    end
end

def readEmail(username, password, mailbox, responseUrl)  
    begin 
    imap = Net::IMAP.new('imap.gmail.com',993,true)
    imap.login(username, password)
    imap.select(mailbox)
 
    rescue Net::IMAP::NoResponseError => error 
      logger.error "Error message : " + error 
    end

    destFolder = 'other'
    mailIds = imap.search(['ALL'])
    mailIds.each do |id|
        msg = imap.fetch(id,'BODY[]')[0].attr['BODY[]']
        mail = Mail.read_from_string msg
        data = Hash.new
        
        if  mail.nil?
           logger.info "mail is empty, skip it"
           next
        end
 
        data = extractEmail(mail,imap)
        destFolder = data['destFolder']
        data.delete('destFolder')

        logger.info "Post data to responseurl : #{data.to_json}" 
        begin
        response = RestClient.post responseUrl, :data => data.to_json, :content_type => 'application/json'
      
        case response.code
        when 200 || 201
           logger.info "send request successfully! Response code is : #{reponse.code}"
           logger.info "The response body is : #{response.body}"

           to_address = response.to_str
           if not to_address.empty?
              logger.info "Forward email to bosses : #{to_address} for user : #{data['email']}"
              forwardEmail(mail,username,password,to_address)
           else
              logger.error "No boss email returned for user : #{data['email']}"
           end
         end

         rescue => ex 
             logger.error "orderId: #{data['order_no']" + ex.inspect
        end

        imap.copy(id, destFolder)
        imap.store(id, "+FLAGS",[:Deleted])
        logger.info "move email : #{data['order_no']} to folder #{destFolder}"
   end
   imap.logout()
   imap.disconnect() 
end

def extractEmail(mail, imap)
      af_order_re = /.*?order #\d+ confirmation.*/
      af_ship_re = /.*?order #\d+ has shipped.*/
      e_receipt_re = /.*?your\s*e-receipt\s*from.*/

        data = Hash.new

        subject = mail.subject.downcase       
        
        if subject.empty? || subject.nil?
           logger.error 'no subject for mail!'
        end

        content = getEmailContent(mail)

        if content.empty? || content.nil?
           logger.error "empty email"
        end

        if m=af_order_re.match(subject)
           data = processEmail(content)
           data['destFolder'] = "OrderConfirmation"
           data['order_status'] = "ordered"
        end

        if m=af_ship_re.match(subject)
           data = processEmail(content)
           data['order_status'] = 'shipped'
           data['tracking_no'] = '1234567'
           data['destFolder'] = "ShippingConfirmation"
        end
  
        if m = e_receipt_re.match(subject)
           data = processEreceipt(content)
           data['order_status']="shipped"
           data['tracking_no'] = ''
           data['destFolder'] = "test"
           orderId = getOrderId(content)
           data['order_no'] = orderId

           if not /.*?\d{9,}.*?/.match(subject) and not orderId.empty?
              newMail = Mail.new
              newMail = mail
              newMail.subject = mail.subject<<" Order #"<<orderId
              #imap.append(data['destFolder'],newMail.to_s)
              #imap.store(id, "+FLAGS",[:Deleted])
           end
        end
          data['email'] = mail.from.to_s 

          data['brand'] = getBrandName(subject)
         
          return data
end

#getBrandName
def getBrandName(subject)
    if subject.empty? || subject.nil?
       logger.error "Email doesn't have subject"
    end

    if subject.include? 'abercrombie' 
       return 'Abercrombie & Fitch'
    elsif subject.include? 'hollister'
       return 'Hollister'
    else
      return 'Other'
    end
end

#get email content as string
def getEmailContent(message)
    content = ""
    if message.multipart?
    
      logger.info "Email : #{message.subject} is multipart type"

       message.parts.each do |part|
         if part.content_type.include? 'plain'
            content+=part.decode_body.force_encoding('UTF-8') 
         elsif part.content_type.include? 'html'
            content+=Nokogiri::HTML(part.decode_body).text  
         elsif part.multipart?
               content+=getEmailContent(part)    
        end
      end
   elsif message.content_type.include? 'plain' 
         logger.info "Email : #{message.subject} is text type"
         content+=message.decode_body
   elsif message.content_type.include? 'html'
         logger.info "Email : #{message.subject} is html"
         content+=Nokogiri::HTML(message.decode_body).text
   end  

  return content 
end

#get orderId from E-Receipt
def getOrderId(emailContent) 
    storeId_re = /.*?store\s*(\d+).*?/
    transId_re = /.*?trans.*?(\d+).*?/
    dateId_re = /.*?date\/time.*?(\d{4}-\d{2}-\d{2}).*/
    orderId = ''
    
    emailContent.each_line do |line|
         line = line.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :replace => '?')
         line = line.gsub("/[*|>]|=09/","").downcase<<' '
         line = line.strip
         
         if line.empty? || line.nil?
            next
         end
        
         if result = storeId_re.match(line)
            orderId << result.captures[0]
            next
         end
         
         if result = transId_re.match(line)
            orderId << result.captures[0]
         end

         if result = dateId_re.match(line)
            orderId << result.captures[0].gsub('-','')
            return orderId
         end
   end 
end


def processEmail(emailContent)
    orderId_re =/.*?order.*?#:\D*(\d+).*?/ 
    orderDate_re = /.*?order\s*date:.*?(\d{2}\/\d{2}\/\d{4}).*/
    shipDate_re = /.*?ship\s*date:.*?(\d+\/\d+\/\d+).*/
    subTotal_re = /.*?subtotal.*?\$?(\d+\.\d{2}).*?shipping.*?\$?(\d+\.\d{2}).*?tax.*?\$?(\d+\.\d{2}).*?total.*?\$?(\d+\.\d{2}).*/
    item_re = /.*?\D?(\d{9})\D?.*?/
    price_re = /^\s*(?:price)?\$?(\d+\.\d+).*/
    start_re = /.*item\s*description.*/
    end_re = /.*subtotal.*/
    total_re = /.*discount.*/

    start = false
    item = ''
    price = ''
    items = Array.new
    item0 = Hash.new
    totalStr = ''
    total = false
    dataH = Hash.new

     emailContent.each_line do |line|
         line = line.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :replace => '?')
         line = line.gsub("/[\*|>]|=09/","").downcase<<' '
         line = line.strip.to_s

         if line.empty?
            next
         end
   
         if result = orderId_re.match(line)
            orderId = result.captures[0]
            dataH['order_no']=orderId 
            next
         end

         if result = shipDate_re.match(line)
             shipDate = result.captures[0]
             dataH['shipping_date'] = Date.strptime(shipDate, "%m/%d/%Y").strftime("%Y-%m-%d")
             next
          end

         if result = orderDate_re.match(line)
             orderDate = result.captures[0]
             dataH['order_date'] = Date.strptime(orderDate, "%m/%d/%Y").strftime("%Y-%m-%d")
             next
          end
         
         if result = start_re.match(line)
             start = true
             next
         end
        
 
         if start
            if result = item_re.match(line)
               item = result.captures[0]
               item0['code'] = item.to_i
            end

           if result = price_re.match(line)
              price = result.captures[0]
              item0['price'] = price.to_f
              if not item0['code'].nil?
                 items.push(item0)
              end
              next
           end 
         end

         if  total
             totalStr.concat(line)
         end

         if result = end_re.match(line)
            start = false
            totalStr.concat(line)
            total = true
            next 
         end 

         if result = total_re.match(line)
            total = false
            totalStr = totalStr.split.join(' ')
            next
         end

        if result = subTotal_re.match(totalStr)
           subtotal,ship,tax,total = result.captures
           dataH['subtotal'] = subtotal.to_f
           dataH['total'] = total.to_f
           dataH['tax'] = tax.to_f
           dataH['shipping'] = ship.to_f
           dataH['items'] = items
           return dataH
         end
     end
      
end

def processEreceipt(emailContent)
    storeId_re =/.*?store.*?(\d+).*/
    trans_re=/.*?trans.*?(\d{4,5}).*/
    trans_orderDate_re = /.*?trans.*?(\d+).*?date\/time.*?(\d{4}-\d{2}-\d{2}).*?\d{2}:?\d{2}.*/
    orderDate_re = /.*?date\/time.*?(\d{4}-\d{2}-\d{2}).*?\d{2}:?\d{2}.*/
    subTotal_re = /.*?subtotal.*?\$?(\d+\.\d{2}).*?total.*?\$?(\d+\.\d{2}).*/
    tax_re = /.*?subtotal.*?\$(\d+\.\d{2}).*?tax.*?\$(\d+\.\d{2}).*?total.*?\$(\d+\.\d{2}).*/
    item_re = /.*?(\d{9}).*/
    item1_re = /.*?(\d{9}).*?\$\d+\s*\.?\d+\s*$/
    price_re = /^\s*\$?(\d+\.\d{2})\s*$/
    price1_re = /.*?\$\d+\.\d+\s*\$(\d+\.\d+)\s*$/
    item_price_re = /.*?\$(\d+\.\d{2})\s*(\d{9}).*/     
    end_re = /.*change.*?due.*/
    total_re = /.*?subtotal.*?/

    item = ''
    price = ''
    start = false
    trans = ''
    storeId = ''
    item0 = Hash.new
    items = Array.new
    dataH = Hash.new
    totalStr = ''
    total = false

     emailContent.each_line do |line|
         line=line.gsub('\*|\t','').downcase<<' '
         line = line.strip.to_s

         if line.empty?
            next
         end

         if  total
             totalStr.concat(line)
         end

         if result = total_re.match(line)
            totalStr.concat(line)
            total = true
            next
         end

         if result = end_re.match(line)
            total = false
            start = false
            totalStr = totalStr.split.join(' ')
            next
         end

        if result = subTotal_re.match(totalStr)
           subtotal,total = result.captures
           dataH['total'] = total.to_f
           dataH['subtotal'] = subtotal.to_f
           dataH['tax'] = 0.00
           dataH['shipping'] = 0.00
           dataH['items'] = items
           puts "total and subtotal"
           puts subtotal
           puts total
           return dataH
        end

        if result = tax_re.match(totalStr)
           subtotal,tax,total = result.captures
           dataH['subtotal'] = subtotal.to_f
           dataH['tax'] = tax.to_f
           dataH['total'] = total.to_f
           dataH['shipping'] = '0.00'
           dataH['items'] = items
           return dataH
        end

        if result = storeId_re.match(line)
            storeId =  result.captures[0]
            next
        end
        
        if result = trans_orderDate_re.match(line)
           trans,date = result.captures
           dataH['order_no'] = storeId<<trans<<date.gsub('-','')
           dataH['order_date'] = date
           dataH['shipping_date'] = date
           start = true
           next
        end

        if result = orderDate_re.match(line)
           date = result.captures[0]
           dataH['order_no'] = storeId<<trans<<date.gsub('-','') 
           dataH['order_date'] = date
           dataH['shipping_date'] = result.captures[0]
           start = true
           next
        end
  
        if start
            if result = item_price_re.match(line)
              price,code = result.captures
              item0['price'] = price.to_f
              items.push(item0)
              item0['code'] = code.to_i
              next
            end

           if result = item1_re.match(line)
              item0['code'] = result.captures[0].to_i
              next
           end

           if result = price1_re.match(line)
              item0['price'] = result.captures[0].to_f
              if not item0['code'].empty?
                 items.push(item0)
              end
              next
           end

           if result = item_re.match(line)
              item0['code'] = result.captures[0].to_i
              next
           end

           if result = price_re.match(line)
              item0['price'] = result.captures[0].to_f
              items.push(item0)
              next
           end

        end

         if result = trans_re.match(line)
            trans = result.captures[0]
            next
         end
          
     end

end


readEmails
