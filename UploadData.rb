require 'net/imap'
require 'rest-client'
require 'json'
require 'rubygems'

require File.dirname(__FILE__) + '/Logger'

class UploadData
   @url
   @@response
   @@responseStatus
   @@responseBody
   def initialize(url)
       # Instance variables
       @url = url
  end
 
  def postData(data)
      begin
      @@response = RestClient.post @url, data.to_json, :content_type => 'application/json', :accept => 'application/json'
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

  def getResponseCode
      if @@response.include? "422"      
         @@responseCOde = 422
      else 
         @@responseCOde = @@response.headers.to_hash[:status]
      end
  end

  def getResponseBody
       
  end
  
  def self.response
      @@response
  end
 
  def self.responseCode
      @@responseCode
  end

  def self.responseBody
      @@responseBody
  end

end

url = 'http://ourtradingplatform:otp$api*secrect@test.uscaigou.com/api/v1/orders/new_email'
data =JSON.parse(%Q{{"order_no":"92049904053","order_date":"2014-05-23","shipping_date":"2014-05-24","subtotal":361.8,"total":361.8,"tax":0.0,"shipping":0.0,"items":[{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0},{"code":610674037,"price":34.0}],"order_status":"other","brand":"Abercrombie & Fitch","email":"kangyihong001@gmail.com"}})

uploadData = UploadData.new(url)
uploadData.postData(data)

