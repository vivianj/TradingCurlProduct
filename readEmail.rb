require 'mail'
require 'net/imap'
require 'net/smtp'
  
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
   puts email
   m=af_order_re.match(mail.subject)
    unless m
      puts "order email"
      puts mail.subject
      puts mail.from
   end
   puts mail.text_part.body.to_s
  # puts mail.html_part.body.to_s
end
imap.logout()
imap.disconnect() 
