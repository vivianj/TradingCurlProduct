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
require File.dirname(__FILE__) + '/Extractor'
require File.dirname(__FILE__) + '/Account'
require File.dirname(__FILE__) + '/UploadData'

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
    uploadData = UploadData.new(responseUrl)
    readEmail(account,mailbox,uploadData)
end

def readEmail(account, mailbox, uploadData)  
    
    imap = account.create_imap
    imap.select(mailbox)

    mailIds = imap.search(['ALL'])
    mailIds.each do |id|
        msg = imap.fetch(id,'BODY[]')[0].attr['BODY[]']
        mail = Mail.read_from_string msg
        
        if  mail.nil?
           logger.info "email is empty, skip it"
           next
        end
 
        logger.info "Start processing the new email : #{mail.subject}"
        extractor = Extractor.new(mail)
        
        if extractor.extractEmail?
           data = extractor.orderData

           EmailProcessor::logger.info "Extracted the correct data and starting to submit to the database"
           uploadData.post(data)

           if not uploadData.isSuccess?
              EmailProcessor::logger.info "Submit the data failure!"
              sendErrorMessage(account, uploadData.responseBody)
           else
              
              destFolder = getDestFolder(imap, data['brand'], data['order_status'])
              
              if not /.*?order\s*#\d+.*/.match(mail.subject.downcase) and not data['order_no'].nil?
                newSubject = mail.subject << "Order #" << data['order_no']
              else 
                newSubject = mail.subject
              end

              forwardEmail(mail, newSubject, account, uploadData.responseBody)
              moveMessage(imap, destFolder, mail, id, data['order_no'])
           end
        end
   end
   account.close_imap
end

def loadPropertyFile(filePath)
    if File.exist?(filePath)
       EmailProcessor::logger.info "Loading the property file #{filePath}"
       properties = YAML.load_file(filePath)
       return properties
    else
       EmailProcessor::logger.error "The property file - #{filePath} does not exist"
    end
end

def getDestFolder(imap, brand, orderStatus)
    folder  = brand.gsub(/[^0-9a-zA-Z]/,'')
    logger.info "cleaned brand name is #{folder}"
    if not imap.list(folder, orderStatus) and  not folder.nil?
      imap.create(folder+'/'+orderStatus)
      return folder+'/'+orderStatus
    elsif folder.nil? and not imap.list('', orderStatus)
        imap.create(orderStatus)
        return orderStatus
    end
end

def moveMessage(imap, destFolder, mail, messageId, orderId)
    if not /.*?order\s*#\d+.*/.match(mail.subject.downcase) and not orderId.nil?
       newMail = Mail.new
       newMail = mail
       newMail.subject = mail.subject << "order #{orderId}"
       imap.append(destFolder, newMail.to_s)
    else
      imap.copy(messageId, destFolder)
    end

    logger.info "move email : #{orderId} to folder #{destFolder}"
    imap.store(messageId, "+FLAGS",[:Deleted])
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
       logger.error 'Got error : #{response}'
    end
    
    return false
end
end

EmailProcessor.readEmails
