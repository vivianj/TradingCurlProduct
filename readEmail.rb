require 'rubygems'
require 'mail'
require 'net/imap'
require 'net/smtp'
require 'nokogiri'
require 'rest_client'
require 'json'
require 'date'
require File.dirname(__FILE__) + '/Logger'
require File.dirname(__FILE__) + '/sendEmails'
require File.dirname(__FILE__) + '/extractEmails'
require File.dirname(__FILE__) + '/Account'

module EmailProcessor

include Log
module_function

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
    account = Account.new(username, password)
    readEmail(account,mailbox,responseUrl)

end

def loadPropertyFile(filePath)
    if File.exist?(filePath)
       logger.info "Loading the property file #{filePath}"
       properties = YAML.load_file(filePath)
       return properties
    else
     logger.error "The property file - #{filePath} does not exist"
    end
end

def connectEmail(username, password, mailbox)
    begin 
    imap = Net::IMAP.new('imap.gmail.com',993,true)
    imap.login(username, password)
    imap.select(mailbox)
 
    rescue Net::IMAP::NoResponseError, Net::IMAP::ResponseError, Net::IMAP::ByeResponseError => ex
      logger.error "Error message : " + ex.message
    end

    return imap
end

def readEmail(account, mailbox, responseUrl)  
    
    imap = account.create_imap
    imap.select(mailbox)

    mailIds = imap.search(['ALL'])
    mailIds.each do |id|
        msg = imap.fetch(id,'BODY[]')[0].attr['BODY[]']
        mail = Mail.read_from_string msg
        data = Hash.new
        
        if  mail.nil?
           logger.info "email is empty, skip it"
           next
        end
 
        data = extractEmail(mail,imap)
        
        response = submitData(data,responseUrl)
         if not /.*?order\s*#\d+.*/.match(mail.subject.downcase) and not data['order_no'].nil?
          newMail = Mail.new
          newMail = mail
          newMail.subject = mail.subject << "Order #"<< data['order_no']
          success= processResponse(newMail,account,response)
          if success
             destFolder = getDestFolder(imap, data['brand'], data['order_status'])
             imap.append(destFolder, newMail.to_s)
           end
        else
            success = processResponse(mail,account,response)
            if success
               destFolder = getDestFolder(imap,data['brand'], data['order_status'])
               imap.copy(id, destFolder)
            end
        end
      
        imap.store(id, "+FLAGS",[:Deleted])
        logger.info "move email : #{data['order_no']} to folder #{destFolder}"
   end
   account.close_imap

end

def submitData(data,responseUrl)
       
       logger.info "Submit data to responseurl : #{data}" 

        begin
        response = RestClient.post responseUrl, data, :content_type => 'application/json', :accept => 'application/json'
      
        case response.code
        when 200 || 201
           logger.info "Send request successfully! Response code is : #{reponse.code}, Body : #{response.body}"

           to_address = response.body.to_s
           if not to_address.empty?
              logger.info "Forward email to bosses : #{to_address} for user : #{data['email']}"
              retrun response
           else
              logger.error "No boss email returned for user : #{data['email']}"
           end
         end

         rescue => ex 
             logger.error "orderId: #{data['order_no']}" + ex.inspect.to_s
             return ex.inspect.to_s
        end
end

def processResponse(message,account, response)
    logger.info "response : #{response}"
    if response.to_s.include? '200' or response.to_s.include? '201'
         to_address = response.body
         forwardEmail(message, account, to_address)
         return true
    elsif response.to_s.include? '422'
      sendEmailToUser(account, response, message.from[0].to_s)
    else
       logger.error 'Got error when submit the data'
    end
    
    return false
end
end

EmailProcessor.readEmails
