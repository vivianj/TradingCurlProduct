require 'mail'
require 'net/imap'
require 'net/smtp'

def readEmail  
   af_order_re = /.*?abercrombie & fitch order #.*?\d+ confirmation.*/
   af_ship_re = /.*abercrombie & fitch order #.\d+ has shipped./
 
   imap = Net::IMAP.new('imap.gmail.com',993,true)
   imap.login('jiangyy12@gmail.com', 'jane@8612')
   imap.select('AF')
   mailIds = imap.search(['ALL'])
   mailIds.each do |id|
   msg = imap.fetch(id,'RFC822')[0].attr['RFC822']
   mail = Mail.read_from_string msg
   
   puts "email content:"
   #puts mail
   m=af_order_re.match(mail.subject)
    unless m.nil?
      puts "order email"
      puts mail.subject
      puts mail.from
   end
   processEmail( mail.text_part.body.to_s)

   #puts mail.text_part.body.to_s
   end
   imap.logout()
   imap.disconnect() 
end

def processEmail(emailContent)
    orderId_re =/.*?order\s*#:.*?(\d+).*/ 
    orderDate_re = /.*order\s*date:.*?(\d+\/\d+\/\d+).*/
    shipDate_re = /.*ship\s*date:.*?(\d+\/\d+\/\d+).*/
    #subTotal_re = 
    item_re = /.*?\D(\d{9})\D.*?/
    price_re = /^\s*(?:price)?\$?(\d+\.\d+).*/
    start_re = /.*item\s*description.*/
    end_re = /.*subtotal.*/
    total_re = /.*discount.*/

    start = false
    item = ''
    price = ''
    items = Hash.new
    totalStr = ''
    total = false

     emailContent.each_line do |line|
         if line.empty?
            next
         end
    
        if result = orderId_re.match(line.downcase)
            puts result.captures
            next
        end


         if result = shipDate_re.match(line.downcase)
             shipDate = result.captures
             puts shipDate 
             next
          end

         if result = orderDate_re.match(line.downcase)
             puts result.captures
             next
          end
         
         if result = start_re.match(line.downcase)
             start = true
             next
         end
        
 
         if start
            if result = item_re.match(line.downcase)
               item = result.captures
               puts result.captures
               next
            end

           if result = price_re.match(line.downcase)
              price = result.captures
              items.store(item, price)
              puts price
           end 
         end

         if  total
             totalStr.concat(line.downcase)
         end

         if result = end_re.match(line.downcase)
            start = false
            totalStr.concat(line.downcase)
            total = true
            next 
         end 

         if result = total_re.match(line.downcase)
            total = false
            puts totalStr
            next
         end

     end
      
    
end


def saveEmail

end

def forwardEmail
end

def moveEmail
end

readEmail

