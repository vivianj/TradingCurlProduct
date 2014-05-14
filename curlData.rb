require 'nokogiri'
require 'open-uri'
require 'uri'
require 'net/ftp'

URL = "http://www.abercrombie.com/shop/us/womens-pants/kaylie-pants-2137107_01" 
hollister = "http://www.hollisterco.com/shop/us/bettys-skinny-sweatpants/hollister-classic-sweatpants-2181079_01"

def getData(url)
    doc = Nokogiri::HTML(open(url))
    data = doc.css("div[class='data']")
    
    price = data.css("input[name='price']")[0]["value"]
    name = data.css("input[name='name']")[0]["value"]
    color = data.css("input[name='color']")[0]["value"] 
    longSkuId = data.css("input[name='longSku']")[0]["value"]
    longskuid = longSkuId.gsub('-','')
    webCodeId = data.css("input[name='collection']")[0]["value"]
    productId = data.css("input[name='productId']")[0]["value"]
    categoryId = data.css("input[name='catId']")[0]["value"]
    seq = data.css("input[name='cseq']")[0]["value"]

    sizes = doc.css("ul.options li option")
    for i in 1..sizes.length-1
       puts sizes[i]["value"]
       puts sizes[i].text
    end

    if url.include? "hollisterco"
       imgLink = "http://anf.scene7.com/is/image/anf/hol_"+webCodeId+"_"+seq+"_prod1?$holCategoryJPG$" 
    elsif url.include? "abercrombie"
       imgLink = "http://anf.scene7.com/is/image/anf/anf_"+webCodeId+"_"+seq+"_prod1?$anfCategoryJPG$"
    end
    
    #save img into local disk
    File.open(File.basename(longskuid+".jpg"), 'wb'){|f| f.write(open(imgLink).read)}
  
    #upload img to ftp server, then delete the local one
    if uploadImg(longskuid + ".jpg") 
       File.delete(longskuid+".jpg")
    end
     
   puts name
end

def uploadImg(img)
   
    host = "waws-prod-blu-003.ftp.azurewebsites.windows.net"
    file = File.new(img)
    ftp = Net::FTP.new
    ftp.connect(host)
    ftp.login(user="afapp\\$afapp", passwd="Bg8ik95E1uN8hiLq9PBfi7kheHklKpziB8JSE5xi43k7Gn7w0uednrg5l5yA")
    files = ftp.chdir("site/wwwroot/images")
    ftp.putbinaryfile(file)
    ftp.close()
     
    true

rescue Exception => err
   puts "upload the img " + img + " error message :" +err.message
   false

end

getData(url=URL)
