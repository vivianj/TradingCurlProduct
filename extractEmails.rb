require 'date'
require 'mail'

module EmailProcessor

module_function

#getBrandName
def getBrandName(subject)
    if subject.empty? || subject.nil?
       logger.error "Email doesn't have the subject"
       return ''
    end

    if subject.include? 'abercrombie' 
       return 'Abercrombie & Fitch'
    elsif subject.include? 'hollister'
       return 'Hollister'
    else
      return ''
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
def getOrderId(content) 
    storeId_re = /.*?store\s*(\d+).*?/
    transId_re = /.*?trans.*?(\d+).*?/
    dateId_re = /.*?date\/time.*?(\d{4}-\d{2}-\d{2}).*/
    orderId = ''
    
    content.each_line do |line|
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

def getDestFolder(imap, brand, orderStatus)
    if not imap.list(brand, orderStatus) and  not brand.empty?
    	imap.create(brand+'/'+orderStatus)
    	return brand+'/'+orderStatus
    elsif brand.empty? and not imap.list('', orderStatus)
        imap.create(orderStatus)
        return orderStatus
    end
end

def getOrderStatus(subject)
	if subject.include? 'e-receipt'
		orderStatus = 'shipped'
	elsif subject.include? 'shipped'
		orderStatus = 'shipped'
	elsif subject.include 'confirmation'
		orderStatus = 'ordered'
    else
    	orderStatus = 'other'
	end

	return orderStatus
end

def extractEmail(mail, imap)
        data = Hash.new

        subject = mail.subject.downcase       
        
        if subject.empty? || subject.nil?
           logger.error 'no subject for mail!'
        end

        content = getEmailContent(mail)

        if content.empty? || content.nil?
           logger.error "empty email"
        end


        if subject.include? 'e-receipt'
        	data = processEreceipt(content)
        else
        	data = processEmail(content)	
        end

        data['order_status'] = getOrderStatus(subject)
        data['brand'] = getBrandName(subject)
        data['destFolder'] = getDestFolder(imap, data['brand'], data['order_status'])
        data['email'] = mail.from.to_s
=begin          
        if m = e_receipt_re.match(subject)
           orderId = getOrderId(content)
           data['order_no'] = orderId

           if not /.*?\d{9,}.*?/.match(subject) and not orderId.empty?
              newMail = Mail.new
              newMail = mail
              newMail.subject = mail.subject<<" Order #"<<orderId
              mail = newMail
              #imap.append(data['destFolder'],newMail.to_s)
              #imap.store(id, "+FLAGS",[:Deleted])
           end
        end
          
=end
         
         
          return data
end

def processEmail(content)
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

    content.each_line do |line|
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

def processEreceipt(content)
    #storeId_re =/.*?store.*?(\d+).*/
    #trans_re=/.*?trans.*?(\d{4,5}).*/
    #trans_orderDate_re = /.*?trans.*?(\d+).*?date\/time.*?(\d{4}-\d{2}-\d{2}).*?\d{2}:?\d{2}.*/
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
    #trans = ''
    #storeId = ''
    item0 = Hash.new
    items = Array.new
    dataH = Hash.new
    totalStr = ''
    total = false

    content.each_line do |line|
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

        if result = orderDate_re.match(line)
           date = result.captures[0]
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

end
