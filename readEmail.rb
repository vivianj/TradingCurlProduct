require 'mail'
require 'net/imap'
require 'net/smtp'
require 'nokogiri'
require 'RestClient'
require 'json'

def readEmail  
    af_order_re = /.*?order #.*?\d+ confirmation.*/
    af_ship_re = /.*?order #.\d+ has shipped./
    e_receipt_re = /.*?your\s*e-receipt\s*from.*/
 
    imap = Net::IMAP.new('imap.gmail.com',993,true)
    imap.login('jiangyy12@gmail.com', 'jane@8612')
    imap.select('AF')
    destFolder = 'other'
    mailIds = imap.search(['ALL'])
    mailIds.each do |id|
        msg = imap.fetch(id,'RFC822')[0].attr['RFC822']
        mail = Mail.read_from_string msg
        data = Hash.new

       	if m=af_order_re.match(mail.subject.downcase)
           data = processEmail(mail.decode_body)
           destFolder = "OrderConfirmation"
           data['brand'] = 'AF'
           data['order_status'] = "ordered"
        end

        if m=af_ship_re.match(mail.subject.downcase)
           data = processEmail(mail.decode_body)
           data['order_status'] = "shipped"
           destFolder = "ShippingConfirmation"
        end
   
        if m = e_receipt_re.match(mail.subject.downcase)
           content = Nokogiri::HTML(mail.decode_body).text
           data = processEreceipt(content)
           data['order_status']="shipped"
           destFolder = "ShippingConfirmation"
        end
          data['email'] = mail.envelope_from
           
          print data.to_json
          response = RestCient.post('http://localhost:3000/api/v1/orders/new_email', data.to_json, :content_type => 'application/json')
          print response

          imap.copy(id, destFolder)
          imap.store(id, "+FLAGS",[:Deleted])

   end
   imap.logout()
   imap.disconnect() 
end

def processEmail(emailContent)
    orderId_re =/.*?order\s*#:.*?(\d+).*/ 
    orderDate_re = /.*order\s*date:.*?(\d+\/\d+\/\d+).*/
    shipDate_re = /.*ship\s*date:.*?(\d+\/\d+\/\d+).*/
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
         line = line.gsub("/[*|>]|=09/","").downcase + ' '
         line = line.strip

         if line.empty?
            next
         end
    
         if result = orderId_re.match(line)
            orderId = result.captures
             dataH['order_no']=orderId 
            next
         end

         if result = shipDate_re.match(line)
             shipDate = result.captures
             dataH['shipping_date'] = shipDate
             puts shipDate 
             next
          end

         if result = orderDate_re.match(line)
             dataH['order_date']=result.captures
             next
          end
         
         if result = start_re.match(line)
             start = true
             next
         end
        
 
         if start
            if result = item_re.match(line)
               item = result.captures
               item0['code'] = item
            end

           if result = price_re.match(line)
              price = result.captures
              item0['price'] = price
              items.push(item0)
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
           dataH['subtotal'] = subtotal
           dataH['total'] = total
           dataH['tax'] = tax
           dataH['shipping'] = ship
           dataH['items'] = items
           return dataH
         end

     end
      
end

def processEreceipt(emailContent)
    storeId_re =/.*?store.*?(\d+).*/
    trans_re=/.*?trans.*?(\d{4,5}).*/
    orderDate_re = /.*?date\/time.*?(\d{4}-\d{2}-\d{2}).*?\d{2}:?\d{2}.*/
    subTotal_re = /.*?subtotal.*?\$?(\d+\.\d{2}).*?total.*?\$?(\d+\.\d{2}).*/
    tax_re = /.*?subtotal.*?\$(\d+\.\d{2}).*?tax.*?\$(\d+\.\d{2}).*?total.*?\$(\d+\.\d{2}).*/
    item_re = /.*?(\d{9}).*/
    price_re = /^\s*\$?(\d+\.\d{2})\s*$/
    item_price_re = /.*?\$(\d+\.\d{2})\s*(\d{9}).*/     
    end_re = /.*change.*?due.*/
    total_re = /.*?subtotal.*?/

    item = ''
    price = ''
    items = Hash.new
    totalStr = ''
    total = false

     emailContent.each_line do |line|
         line=line.gsub('\*','').downcase

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
            totalStr = totalStr.split.join(' ')
            next
         end

        if result = subTotal_re.match(totalStr)
           subtotal,total = result.captures
           puts "total and subtotal"
           puts subtotal
           puts total
           return
        end

        if result = tax_re.match(totalStr)
           subtotal,tax,total = result.captures
           puts subtotal
           puts tax
           puts total
           return
        end

        if result = storeId_re.match(line)
            puts "storeID"
            puts result.captures
            next
        end

        if result = trans_re.match(line)
           puts "transId"
           trans = result.captures
           puts trans
        end

        if result = orderDate_re.match(line)
           puts "Date:"
           date=result.captures
           puts date
           next
        end

        if result = item_re.match(line)
           item = result.captures
           puts "item"
           puts result.captures
           next
         end

        if result = price_re.match(line)
            price = result.captures
            items.store(item, price)
            puts "price"
            puts price
            next
        end


         if result = item_price_re.match(line)
            price,item0 = result.captures
            items.store(item,price)
            puts "line matchs item price"
            puts item
            puts price
            item = item0
            next
         end

     end

end


readEmail

