#!/usr/bin/ruby

require 'net/http'
require 'net/https'
require 'rexml/document'
require 'uri'
require 'cgi'
require 'json'
require 'time'
include REXML


$stdout.sync = true
$stderr.sync = true
Thread.abort_on_exception = true

ENV['AUTHKEY'] || raise('Missing Environment Variable: AUTHKEY')
ENV['CONTACTSKEY'] || raise('Missing Environment Variable: CONTACTSKEY')
ENV['SYNCGROUP'] || raise('Missing Environment Variable: SYNCGROUP')

hosts = {"auth" => "auth.l42.eu", "contacts" => "contacts.l42.eu"}

server = TCPServer.open(ENV['PORT'])
puts 'server running on port '+ENV['PORT']
loop {
	Thread.start(server.accept) do |client|
		_, _, _, remote_ip = client.peeraddr
		request_time = Time.now.utc.iso8601
		status = "?"
		header = nil
		host = nil
		protocol = "http"
		while line = client.gets
			if header.nil?
				header = line.strip
			end
			if line.start_with?("Host: ")
				host = line.split(': ')[1].strip
			end
			if line.start_with?("X-Forwarded-Proto: ")
				protocol = line.split(': ')[1].strip
			end
			if line == "\r\n"
				break
			end
		end
		if header.nil?
			puts "Incomplete HTTP request, closing connection to "+remote_ip
			client.close
			next
		end
		uristr = header.split(' ')[1]
		uri = URI(uristr)
		path = uri.path.gsub('..','').split('/')
		if uri.query.nil?
			uri_params = {}
		else
			uri_params = CGI.parse(uri.query)
		end
		begin
			case path[1]
				when 'preload'	
					begin
						file = File.new('../../core/preload.xhtml')
					rescue Exception => e
						raise "Preload File Not Found"
					end
					status = 200
					client.puts("HTTP/1.1 200 OK")
					client.puts("Content-Type: application/xhtml+xml")
					client.puts()				
					client.puts(file.read.gsub('$manifest$', ''))
					file.close
				when "sync"
					if uri_params['token'].nil?
						raise "Auth Failure"
					end
					token = uri_params['token'][0]
					if token.nil? or token == ''
						raise "Auth Failure"
					end
					uri = URI.parse('https://'+hosts['auth']+'/data')
					uri.query = URI.encode_www_form("token" => token, "apikey" => ENV['AUTHKEY'])
					response = Net::HTTP.get_response(uri)
					if (response.code == "401")
						raise "Auth Failure"
					end
					if (response.code != "200")
						raise "Auth HTTP Request Failed with "+response.code
					end
					authdata = JSON.parse(response.body)
				
					access_token = authdata['token']
					
					lucos_sync_group = ENV['SYNCGROUP']
					
					case path[2]
						when nil
							status = 200
							client.puts("HTTP/1.1 200 OK")
							client.puts("Content-Type: text/html; Charset=UTF-8")
							client.puts("")
							client.puts("<a href='/sync/import'>Import from Google to lucOS</a> <a href='/sync/export'>Export from lucOS to Google</a>")
						when "import"
							uri = URI.parse("https://www.google.com/m8/feeds/contacts/default/full?group="+URI.escape(lucos_sync_group)+"&max-results=10000")

							http = Net::HTTP.new(uri.host, uri.port)
							http.use_ssl = true
							http.verify_mode = OpenSSL::SSL::VERIFY_NONE
							resp = http.get(uri.request_uri, {'Authorization' => "OAuth "+access_token})
							
							if (resp.code == "401")
								raise "Auth Failure"
							end
							if (resp.code != "200")
								raise "Google HTTP Request Failed with "+response.code
							end
							
							data = Document.new(resp.body)
							status = 200
							client.puts("HTTP/1.1 200 OK")
							client.puts("Content-Type: text/plain; Charset=UTF-8")
							client.puts("")
							
							data.elements.each("feed/entry") { |contactData|
								identifiers = []
								identifiers << {
									:type => 'googlecontact',
									:contactid => contactData.elements['id'].text.split('/').last
								}
								contactData.elements.each('gd:phoneNumber') { |phone|
									identifiers << {
										:type => 'phone',
										:number => phone.text.gsub('+44', '0')
									}
								}
								contactData.elements.each('gd:email') { |email|
									identifiers << {
										:type => 'email',
										:address => email.attributes['address']
									}
								}
								userid = nil
								identifiers.each() { |identifier|
									uri = URI.parse("https://"+hosts['contacts']+"/identify")
									uri.query = URI.encode_www_form(identifier)
									resp = Net::HTTP.get_response(uri)
									if resp.code == "302"
										userid = resp['Location'].split('/').last
										break
									elsif resp.code == "404"
										next
									else
										raise "Identifier HTTP Request failed with "+resp.code
									end
								}
								
								# If no userid is found, then add a new user
								if userid.nil?
									client.puts("Creating new user "+contactData.elements['title'].text+" (Google id:"+identifiers.first[:contactid]+")")
									uri = URI.parse("https://"+hosts['contacts']+"/agents/add")

									http = Net::HTTP.new(uri.host, uri.port)
									resp = http.post(uri.request_uri, URI.escape("name_en")+"="+URI.escape(contactData.elements['title'].text), {'Authorization' => "Key "+ENV['CONTACTSKEY']})

									if resp.code == "302"
										userid = resp['Location'].split('/').last
									else
										raise "Add HTTP Request failed with "+resp.code+"\nBody: "+resp.body
									end
								end
								client.puts("Updating user "+contactData.elements['title'].text+" (lucOS id: "+userid+")")
								uri = URI.parse("https://"+hosts['contacts']+"/agents/"+userid+"/accounts")

								client.puts("https://"+hosts['contacts']+"/agents/"+userid+"/accounts")
								client.puts(identifiers.to_json)
								http = Net::HTTP.new(uri.host, uri.port)
								resp = http.post(uri.request_uri, identifiers.to_json, {'Authorization' => "Key "+ENV['CONTACTSKEY']})
								if resp.code != "204"
									raise "Accounts HTTP Request failed with "+resp.code+"\n"+resp.body
								end
							}
						when "export"
							status = 200
							client.puts("HTTP/1.1 200 OK")
							client.puts("Content-Type: text/plain; Charset=UTF-8")
							client.puts("")
							client.puts("Not yet implemented")
						else
							raise "File Not Found"
					end
				else
					raise "File Not Found"
			end
		rescue Exception => e
			if e.message == "Auth Failure"
				url = protocol+"://"+host+uristr
				status = 302
				client.puts("HTTP/1.1 302 Found")
				client.puts("Location: https://"+hosts['auth']+"/provider?type=google&redirect_uri="+URI.escape(url)+"&scope="+URI.escape("https://www.google.com/m8/feeds/"))
				client.puts("")
			elsif e.message.end_with?("Not Found")
				status = 404
				client.puts("HTTP/1.1 404 "+e.message)
				client.puts
				client.puts(e.message)
			else
				status = 500
				client.puts("HTTP/1.1 500 Internal Error")
				client.puts
				client.puts(e.message)
				client.puts(e.backtrace)
			end
		end
		puts remote_ip+" - - \""+header+"\" ["+request_time+"] "+status.to_s+" -"
		client.close
	end
}
