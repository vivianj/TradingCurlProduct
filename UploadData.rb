require 'rest-client'
require 'json'
require 'rubygems'

require File.dirname(__FILE__) + '/Logger'

module EmailProcessor
include Log
class UploadData
   @url
   @@response
   @@responseStatus = ''
   @@responseBody = ''

   def initialize(url)
       # Instance variables
       @url = url
  end
 
  def post(data)
      begin
      @@response = RestClient.post @url, data, :content_type => 'application/json', :accept => 'application/json'
      @@responseBody =  @@response.to_s
      @@responseStatus = @@response.headers[:status]
             
      rescue => ex 
      puts "Got error: #{ex.inspect}  when submit the data to api "
           @@response = ex.inspect 
           @@responseStatus = @@response.split(/:/)[0]
           @@responseBody = @@response.split(/:/)[1]
      end
         puts @@responseStatus
         puts @@responseBody
   end

  def isSuccess? 
      if @@responseStatus.include? "201" or @@responseStatus.include? "200"
         return true      
      else 
        return false
      end
  end
  
  def responseStatus
      @@responseStatus
  end

  def responseBody
      @@responseBody
  end
end

=begin
url = 'http://ourtradingplatform:otp$api*secrect@test.uscaigou.com/api/v1/orders/new_email'
data =JSON.parse(%Q{{"order_no":"92049904053","order_date":"2014-05-23","shipping_date":"2014-05-24","subtotal":361.8,"total":361.8,"tax":0.0,"shipping":0.0,"items":[{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0}],"order_status":"other","brand":"Abercrombie & Fitch","email":"kangyihong001@gmail.com"}})

uploadData = UploadData.new(url)
uploadData.post(data)
puts uploadData.responseBody
=end

end
