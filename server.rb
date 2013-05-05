#!/usr/bin/ruby -rubygems

require 'net/http'
require 'net/https'
require 'rexml/document'
require 'uri'
require 'cgi'
require 'json'
include REXML


require '../core/resources.rb'

$stdout.sync = true
$stderr.sync = true
Thread.abort_on_exception = true

settings = Hash[*File.read('settings').split(/\s+/)]

Resource.new('lucosjs', 'js', '../core/lucos.js')

server = TCPServer.open(8011)
puts 'server running on port 8011'	
loop {
	Thread.start(server.accept) do |client|
		header = nil
		while line = client.gets
			if header.nil?
				header = line
			end
			if line == "\r\n"
				break
			end
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
				when 'resources'
					Resource.output(client, uri_params)
				when 'preload'	
					begin
						file = File.new('../../core/preload.xhtml')
					rescue Exception => e
						raise "Preload File Not Found"
					end
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
					uri = URI.parse('http://auth.l42.eu/data?token='+URI.escape(token)+'&apikey='+settings['authkey'])
					#uri.query = URI.encode_www_form("token" => uri_params['token'], "apikey" => 'abc') #not suported until ruby 1.9
					response = Net::HTTP.get_response(uri)
					if (response.code == "401")
						raise "Auth Failure"
					end
					if (response.code != "200")
						raise "Auth HTTP Request Failed with "+response.code
					end
					authdata = JSON.parse(response.body)
				
					access_token = authdata['token']
					
					lucos_sync_group = settings['syncgroup']
					
					case path[2]
						when nil
							
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
						
							client.puts("HTTP/1.1 200 OK")
							client.puts("Content-Type: text/plain; Charset=UTF-8")
							client.puts("")
							
							data.elements.each("feed/entry") { |contactData|
								identifiers = []
								identifiers << {
									:type => 16,
									:id => contactData.elements['id'].text.split('/').last
								}
								contactData.elements.each('gd:phoneNumber') { |phone|
									identifiers << {
										:type => 5,
										:id => phone.text.gsub('+44', '0')
									}
								}
								contactData.elements.each('gd:email') { |email|
									identifiers << {
										:type => 9,
										:id => email.attributes['address']
									}
								}
								userid = nil
								identifiers.each() { |identifier|
									uri = URI.parse("http://contacts.l42.eu/identify")
									#uri.query = URI.encode_www_form(identifier) #not suported until ruby 1.9
									uri.query = ""
									identifier.each_pair do |key, val|
										uri.query += URI.escape(key.id2name)+"="+URI.escape(val.to_s)+"&"
									end
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
									client.puts("Creating new user "+contactData.elements['title'].text+" (Google id:"+identifiers.first[:id]+")")
									uri = URI.parse("http://contacts.l42.eu/agents/add")

									http = Net::HTTP.new(uri.host, uri.port)
									resp = http.post(uri.request_uri, URI.escape("name_en")+"="+URI.escape(contactData.elements['title'].text), {'Authorization' => "Key "+settings['contactskey']})

									if resp.code == "302"
										userid = resp['Location'].split('/').last
									else
										raise "Add HTTP Request failed with "+resp.code
									end
								end
								client.puts("Updating user "+contactData.elements['title'].text+" (lucOS id: "+userid+")")
								postdata = ""
								identifiers.each() { |identifier|
									identifier.each_pair do |key, val|
										postdata += URI.escape(key.id2name)+"="+URI.escape(val.to_s)+"&"
									end
								}
								uri = URI.parse("http://contacts.l42.eu/agents/"+userid+"/accounts")

								client.puts("http://contacts.l42.eu/agents/"+userid+"/accounts")
								client.puts(postdata)
								http = Net::HTTP.new(uri.host, uri.port)
								resp = http.post(uri.request_uri, postdata, {'Authorization' => "Key "+settings['contactskey']})
								if resp.code != "204"
									raise "Accounts HTTP Request failed with "+resp.code
								end
							}
						when "export"
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
				url = "http://googlecontactssync.l42.eu"+uristr
				client.puts("HTTP/1.1 302 Found")
				client.puts("Location: http://auth.l42.eu/provider?type=google&redirect_uri="+URI.escape(url)+"&scope="+URI.escape("https://www.google.com/m8/feeds/"))
				client.puts("")
			elsif e.message.end_with?("Not Found")
					client.puts("HTTP/1.1 404 "+e.message)
					client.puts
					client.puts(e.message)
			else
					client.puts("HTTP/1.1 500 Internal Error")
					client.puts
					client.puts(e.message)
					client.puts(e.backtrace)
			
			end
		end
		client.close
	end
}
