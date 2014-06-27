require 'date'
require 'mail'

module EmailProcessor

class Extractor

      @brand 
      @orderStatus = 'other'
      @orderId = ''
      @message  
      @subject
      @content 
      @itemtotal       
      @orderDate
      @shipDate
      @subtotal = 0.0
      @total = 0.0
      @shipping = 0.0
      @tax = 0.0
      @tracking = ''
      
      class<<self
      attr_reader :orderData
      end
      
      @orderData = Hash.new

      def initialize(message) 
          @message = message
          @orderData = Hash.new
          @content = ''
          @itemtotal = 0.0
          @subject = ''
          @brand = ''
          @orderStatus = 'other'
          @subtotal = 0.0
          @total = 0.0
          @shipping = 0.0
          @tax = 0.0
          @trackingNo = ''
      end

      
      def getSubject
          @subject = @message.subject.downcase
          
          EmailProcessor::logger.info "Subject : #{@subject}"
      end
     
      def orderData
          @orderData
      end
 
      def extractEmail?
        e_receipt_re = /.*?e-receipt.*?/
        EmailProcessor::logger.info "Starting to extract!"

        getSubject

        if @subject.empty? || @subject.nil?
           EmailProcessor::logger.error 'no subject for mail!'
        end

        getBrand
        getOrderStatus
        getOrderId

        getEmailContent(@message)

         #:puts"content extracted : #{@content}"
        if @content.empty? || @content.nil?
           EmailProcessor::logger.error "empty email"
        end

        if @subject.include? 'e-receipt'
           EmailProcessor::logger.info "Proces the Ereceipt!"
           processEreceipt
        else
           EmailProcessor::logger.info "Process the website order!"
           processEmail
         end

         if @orderStatus.include? 'shipped'
            @orderData['tracking_no'] = @trackingNo
         end

         @orderData['email'] = @message.from[0]
        return isExtractedCorrect?
      end

      def isExtractedCorrect?
           EmailProcessor::logger.info "Extracted data : #{@orderData}"

          if @tax + @shipping + @subtotal != @total
            EmailProcessor::logger.error "The total is not equal to the sum of subtotal, shipping and tax!"
            return false
          elsif not @itemtotal.round(2).eql?(@subtotal)
                EmailProcessor::logger.error "Subtotal != itemtotal: #{@subtotal} != #{@itemtotal.round(2)}"
                return false
          end
           
          return true
      end

def getBrand
    if @subject.empty? || @subject.nil?
       EmailProcessor::logger.error "Email doesn't have the subject"
    elsif @subject.include? 'abercrombie' 
       @brand='Abercrombie & Fitch'
    elsif @subject.include? 'hollister'
       @brand='Hollister'
    end
    @orderData['brand'] = @brand
    EmailProcessor::logger.info "Brand Name is :#{@brand}"
end

def getEmailContent(message)
    
    if message.multipart?
      EmailProcessor::logger.info "Email : #{message.subject} is multipart type"

       message.parts.each do |part|
         if part.content_type.include? 'plain'
            @content=part.decode_body.force_encoding('UTF-8') 
         elsif part.content_type.include? 'html'
               @content=Nokogiri::HTML(part.decode_body).text  
         elsif part.multipart?
              @content=getEmailContent(part)    
        end
      end
   elsif message.content_type.include? 'plain' 
         EmailProcessor::logger.info "Email : #{message.subject} is text type"
         @content=message.decode_body
   elsif message.content_type.include? 'html'
         EmailProcessor::logger.info "Email : #{message.subject} is html"
         @content=Nokogiri::HTML(message.decode_body).text
   end  
end

def getOrderId 
    subject_re = /.*?order\s*#(\d+).*/
    storeId_re = /.*?store\s*(\d+).*?/
    transId_re = /.*?trans.*?(\d+).*?/
    dateId_re = /.*?date\/time.*?(\d{4}-\d{2}-\d{2}).*/
   
    if result = subject_re.match(@subject)
       @orderId = result.captures[0]
       @orderData['order_no'] = @orderId
    else 
    @content.each_line do |line|
         #line = line.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :replace => '?')
         line = line.force_encoding('UTF-8') 
         line = line.gsub("/[*|>]|=09/","").downcase<<' '
         line = line.strip
         
         if line.empty? || line.nil?
            next
         end
        
         if result = storeId_re.match(line)
            @orderId << result.captures[0]
            next
         end
         
         if result = transId_re.match(line)
            @orderId << result.captures[0]
         end

         if result = dateId_re.match(line)
            @orderId << result.captures[0].gsub('-','')
         end

         @orderData['order_no'] = @orderId
   end 

    EmailProcessor::logger.info "OrderId : #{@orderId}"
  end
end

def getOrderStatus
	if @subject.include? 'e-receipt'
		@orderStatus = 'shipped'
	elsif @subject.include? 'shipped'
		@orderStatus = 'shipped'
	elsif @subject.include? 'confirmation'
		@orderStatus = 'ordered'
	end
  @orderData['order_status'] = @orderStatus
  EmailProcessor::logger.info "Order status : #{@orderStatus}"
end



def processEmail
    orderDate_re = /.*?order\s*date:.*?(\d{2}\/\d{2}\/\d{4}).*/
    shipDate_re = /.*?ship\s*date:.*?(\d+\/\d+\/\d+).*/
    subTotal_re = /.*?subtotal.*?\$?(\d+\.\d{2}).*?shipping.*?\$?(\d+\.\d{2}).*?tax.*?\$?(\d+\.\d{2}).*?total.*?\$?(\d+\.\d{2}).*/
    item_re = /.*?\D?(\d{9})\D?.*?/
    price_re = /^\s*(?:price)?\$?(\d+\.\d+).*/
    start_re = /.*item\s*description.*/
    end_re = /.*subtotal.*/
    total_re = /.*discount.*/

    start = false
    price = 0.0
    item0 = Hash.new
    items = Array.new
    totalStr = ''
    total = false

    @content.each_line do |line|
         line = line.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :replace => '?')
         line = line.gsub("/[\*|>]|=09/","").downcase<<' '
         line = line.strip.to_s

         if line.empty?
            next
         end
   

         if result = shipDate_re.match(line)
             @shipDate = result.captures[0]
             @orderData['shipping_date'] = Date.strptime(@shipDate, "%m/%d/%Y").strftime("%Y-%m-%d")
             next
          end

         if result = orderDate_re.match(line)
             @orderDate = result.captures[0]
             @orderData['order_date'] = Date.strptime(@orderDate, "%m/%d/%Y").strftime("%Y-%m-%d")
             next
          end
         
         if result = start_re.match(line)
             start = true
             next
         end
        
         if start
            if result = item_re.match(line)
               code = result.captures[0].to_i
               item0['code'] = code
            end

           if result = price_re.match(line)
              price = result.captures[0].to_f
              item0['price'] = price

              if item0.has_key?('code')
                 items.push(item0)
                 @itemtotal = @itemtotal + price
              end
              item0 = Hash.new()
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
           @subtotal = subtotal.to_f
           @total = total.to_f
           @tax = tax.to_f
           @shipping = ship.to_f
           
           @orderData['subtotal'] = subtotal.to_f
           @orderData['total'] = total.to_f
           @orderData['tax'] = tax.to_f
           @orderData['shipping'] = ship.to_f
           @orderData['items'] = items
         end
     end
      
end

def processEreceipt
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
    item0 = Hash.new
    items = Array.new
    totalStr = ''
    total = false

    @content.each_line do |line|
         line = line.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :replace => '?')
         line = line.gsub('\*|\t','').downcase<<' '
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

        if result = tax_re.match(totalStr)
           subtotal,tax,total = result.captures
           @tax = tax.to_f
           @total = total.to_f
           @subtotal = subtotal.to_f

           @orderData['total'] = total.to_f
           @orderData['subtotal'] = subtotal.to_f
           @orderData['tax'] = @tax 
           @orderData['shipping'] = @shipping 
           @orderData['items'] = items
           return
        end

        if result = subTotal_re.match(totalStr)
           subtotal,total = result.captures
           @subtotal = subtotal.to_f
           @total = total.to_f
           
           @orderData['subtotal'] = subtotal.to_f
           @orderData['tax'] = @tax
           @orderData['total'] = total.to_f
           @orderData['shipping'] = @shipping 
           @orderData['items'] = items
           return
        end

        if result = orderDate_re.match(line)
           date = result.captures[0]
           @orderDate = date
           @shipDate = date

           @orderData['order_date'] = date
           @orderData['shipping_date'] = date 
           start = true
           next
        end
  
        if start
            if result = item_price_re.match(line)
               price,code = result.captures
           
              item0['price'] = price.to_f
              #puts  "price is "<<price.to_s << "Total is " << @itemtotal.to_s
              @itemtotal = @itemtotal + price.to_f
              items.push(item0)
              item0 = Hash.new
              item0['code'] = code.to_i
              next
            end

           if result = item1_re.match(line)
              item0['code'] = result.captures[0].to_i
              next
           end

           if result = price1_re.match(line)
              item0['price'] = result.captures[0].to_f
              if item0.has_key?('code')
                     items.push(item0)

                     @itemtotal = @itemtotal + item0['price']
                    # puts  "price is "<< item0['price'].to_s << "Total is " << @itemtotal.to_s
              end
              item0 = Hash.new
              next
           end

           if result = item_re.match(line)
              item0['code'] = result.captures[0].to_i
              next
           end

           if result = price_re.match(line)
              item0['price'] = result.captures[0].to_f
              if item0.has_key?('code')
                     items.push(item0)

                     @itemtotal = @itemtotal + item0['price']
              end
              item0 = Hash.new
              next
           end
        end
     end
   end

 end
end