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
    #name = getValue(data1=data, name1='name')
    color = data.css("input[name='color']")[0]["value"] 
    longSkuId = data.css("input[name='longSku']")[0]["value"]
    webCodeId = data.css("input[name='collection']")[0]["value"]
    productId = data.css("input[name='productId']")[0]["value"]
    categoryId = data.css("input[name='catId']")[0]["value"]
    seq = data.css("input[name='cseq']")[0]["value"]

    if url.include? "hollisterco"
       imgLink = "http://anf.scene7.com/is/image/anf/hol_"+webCodeId+"_"+seq+"_prod1?$holCategoryJPG$" 
    elsif url.include? "abercrombie"
       imgLink = "http://anf.scene7.com/is/image/anf/anf_"+webCodeId+"_"+seq+"_prod1?$anfCategoryJPG$"
    end

    File.open(File.basename(longSkuId.gsub('-','')+".jpg"), 'wb'){|f| f.write(open(imgLink).read)}
    puts name
end

def getValue(data1, name1)
    return data1.css(input[name=name1])[0]["value"]
end

def uploadImg(img)
    host = "waws-prod-blu-003.ftp.azurewebsites.windows.net"

    file = File.new(img)
    ftp = Net::FTP.new(host)
    ftp.login(user="afapp\$afapp", passwd="Bg8ik95E1uN8hiLq9PBfi7kheHklKpziB8JSE5xi43k7Gn7w0uednrg5l5yA")
    ftp.putbinaryfile(file, "/site/wwwroot/#{File.basename(file)}")
    ftp.close()
    ftp.quit()
end

uploadImg(img='1564250149023.jpg')
#getData(url=URL)
