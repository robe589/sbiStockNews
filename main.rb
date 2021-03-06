#coding: utf-8
require 'bundler'
Bundler.require
require 'pp'
require 'csv'


require './myid'
require './twitterApi'
require './GmailSend'

def main()	
	baseUrl='https://site2.sbisec.co.jp'
	agent=Mechanize.new
	savePath="data/"
	sendStr=String.new	
	begin
		FileUtils.mkdir_p(savePath) unless FileTest.exist?(savePath)
		sbiLogin(baseUrl,agent)
		#保有リストを取得
		stockList=CSV.read('../holdStockList.csv')
		stockList.delete_at(0)
		#保有銘柄ごとのニュースを取得
		stockNews=Hash.new
		companyName=Hash.new
		stockList.each_with_index do |code,i|
			pp code[0]
			stockNews[code[0]]=getStockNews(agent,baseUrl,code[0])
			#会社名を取得
			stockInfo=JpStock.quote(:code=>code[0])
			pp stockInfo
			next if stockInfo ==nil
			companyName[code[0]]=stockInfo.company_name
		end
		pp companyName
		#きょうのニュースを検索し、メールで送信
		nowDate=Time.now.strftime("%m/%d")
		isNews=false#全部の銘柄でニュースが1つでもあったらtrue
		isStockNews=false
		stockNews.each do |key,value|
			value.each_with_index do |news,i|
				date=news['date'][0,5]
				if  date==nowDate
					if isStockNews==false
						isStockNews=true
						sendStr+=key+'['+companyName[key]+']のニュース'+"\n"
					end
					sendStr+=news['date']+':'+news['title']+"\n"+news['content']+"\n\n"
					isNews=true
				end
			end
			if isStockNews==true
				isStockNews=false
				sendStr+="\n"
			end
		end		
		gmailSend=GmailSend.new($senderAddress,$gmailPassword)
		pp sendStr
		if isNews==true
			gmailSend.sendMail('stockInfo589@gmail.com','本日の保有銘柄ニュース',sendStr)
			puts 'メール送信完了'
		else
			sendStr='ニュースが１つもありませんでした'
			gmailSend.sendMail('stockInfo589@gmail.com','本日の保有銘柄ニュース',sendStr)
		end
	end
	puts '正常終了'
end

def sbiLogin(baseUrl,agent)
	loginUrl=baseUrl+'/ETGate/'
	# ログイン処理
	agent.get(loginUrl) do |page|
		page.form_with(:name=> 'form_login') do |form|
			form.field_with(:name => 'user_id').value =$login_id
			form.field_with(:name => 'user_password').value = $login_password
		end.submit
	end
end

def csvSave(body,savePath)
	#現在時刻を取得
	date=Time.now.strftime("%Y%m%d")
	date="20150706"
	first=0
	csvSavePath=savePath+date+".csv"
	CSV.open(csvSavePath,"w") do end
	body.xpath('//tr[@align="center"]').each_with_index do |node1,i|
		list=Array.new
		node1.xpath('./td').each_with_index do |node2,j|
			if node2.text=='取引' and first==0
				first=1
			elsif first==0
				next
			elsif node2.text=='株式(現物/NISA預り)合計'
				break
			end
			list[j]=node2.text
		end
		list.delete_at(0)
		list.delete_at(-1)
		CSV.open(csvSavePath,"a") do |csv|
			csv<<list
		end
	end
end

def getStockNews(agent,baseUrl,code)
	url=baseUrl+'/ETGate/?_ControlID=WPLETsiR001Control&_PageID=WPLETsiR001Idtl20&_DataStoreID=DSWPLETsiR001Control&_ActionID=DefaultAID&s_rkbn=&s_btype=&i_stock_sec='+code+'&i_dom_flg=1&i_exchange_code=TKY&i_output_type=1&exchange_code=TKY&stock_sec_code_mul='+code+'&ref_from=1&ref_to=20&wstm4130_sort_id=&wstm4130_sort_kbn=&qr_keyword=&qr_suggest=&qr_sort='
	page=agent.get(url)
	body=Nokogiri::HTML(page.body)
	news=Array.new
	
	body.xpath('//td[@class="sbody_today"]').each_with_index do |node,i|
		news[i]=Hash.new
		text=removeToken(node.text)
		#?を削除
		newText=text[1,5]+' '+text[8,5]	
		news[i]['date']=newText
		node.xpath('./..//a').each do |node1|
		    contentUrl=baseUrl+node1.values[0]
			content=getContent(agent,contentUrl)
			news[i]['title']=removeToken(content['title'])
			news[i]['content']=content['content']
			puts news[i][:content]
		end
	end

	return news
end

def removeToken(text)
	while(text.index("\r")!=nil)do text.slice!("\r") end
	while(text.index("\n")!=nil)do text.slice!("\n") end
	while(text.index("\t")!=nil)do text.slice!("\t") end

	return text
end

def getContent(agent,getUrl)
	page=agent.get(getUrl)
	body=Nokogiri::HTML(page.body)

	text=Array.new
	body.xpath('//td[@class="mbody"]').each_with_index do |node,i|
		text[i]=node.text
	end
	content=Hash.new
	content['title']=text[0]
	content['content']=text[1]

	return content
end

main()
