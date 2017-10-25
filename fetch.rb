class Downloader
	require 'net/http'
	require 'json'
	require 'fileutils'
	require 'zlib'
	require "fastimage"
	require "find"

	MIN_WIDTH = 1920
	MIN_HEIGHT = 1080
	RATIO_PATH = 'ratio_out\\'
	DOWNLOAD_PATH = 'p_downloads\\'
	TOP_COUNT = 20
	SUBS = [ 	"AmateurEarthPorn",
				"BeachPorn",
				"InfraredPorn",
				"LakePorn",
				"EarthPorn",
				"BotanicalPorn",
				"WaterPorn",
				"SeaPorn",
				"SkyPorn",
				"FirePorn",
				"DesertPorn",
				"WinterPorn",
				"AutumnPorn",
				"WeatherPorn",
				"SpacePorn",
				"BeachPorn",
				"MushroomPorn",
				"SpringPorn",
				"SummerPorn",
				"LavaPorn",
				"LakePorn",
				"CityPorn",
				"VillagePorn",
				"RuralPorn",
				"ArchitecturePorn",
				"CabinPorn",
				"ChurchPorn",
				"AbandonedPorn",
				"InfrastructurePorn",
				"MachinePorn",
				"CarPorn",
				"MotorcyclePorn",
				"RidesPorn",
				"StarshipPorn",
				"BridgePorn",
				"SpaceFlightPorn",
				"AnimalPorn",
				"ClimbingPorn",
				"AgriculturePorn",
				"TeaPorn",
				"BonsaiPorn",
				"ExposurePorn",
				"MacroPorn",
				"MicroPorn",
				"AerialPorn",
				"ApocalypsePorn",
				"InfraredPorn",
				"HellscapePorn" ]

	# SUBS = [ "FoodPorn" ]
	TIMESPANS = ['hour', 'day', 'week', 'month', 'year', 'all']

	def run
		puts "Getting max #{SUBS.length * TOP_COUNT} images."
		sleep 1
		SUBS.each do |sub|
			uri = build_uri sub, TIMESPANS[2], TOP_COUNT
			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true;
			api_resp = http.get(uri.request_uri).body

			if api_resp.empty?
				puts "Failed to get any links from #{uri}"
				next
			end

			json = JSON.parse(api_resp)
			posts = json['data']['children']
			posts.each do |post|
				download_image post['data']['url'], DOWNLOAD_PATH + sub + '\\', sub
			end
		end

		files = Array.new
		Find.find('.') do |file|
			files << file if not file.include? "ratio_out" and file.end_with? ".jpg"
		end
		puts "Found #{files.length} files"
		files.each do |file|
			begin
				diemensions = FastImage.size(file)
				next if diemensions.nil?

				ratio = (diemensions[0].to_f / diemensions[1].to_f).round(2).to_s.ljust(4, '0')
				FileUtils.mkpath RATIO_PATH + ratio unless File.exists? RATIO_PATH + ratio

				puts "Copying file from #{file} to #{RATIO_PATH + ratio + '\\' + File.basename(file)}"
				FileUtils.mv file, RATIO_PATH + ratio + '\\' + File.basename(file) unless diemensions[0] < MIN_WIDTH or diemensions[1] < MIN_HEIGHT
				FileUtils.rm file if diemensions[0] < MIN_WIDTH or diemensions[1] < MIN_HEIGHT
			rescue NoMethodError
				puts "#{file} was not really an image"
			end
		end
	end

	def build_uri sub, time, limit
		return URI.parse("https://www.reddit.com/r/#{sub}/top/.json?sort=top&t=#{time}&limit=#{limit}")
	end

	def download_image url, save_path, sub
		final_url = ""
		if url.end_with? ".jpg" or
			url.end_with? ".jpeg" or
			url.end_with? ".png" or
			url =~ /^https:\/\/drscdn.500px.org\/photo\/[0-9]+\/[a-z%0-9]+\/[a-z0-9]+$/i
			final_url = url
		elsif url =~ /^http:\/\/imgur.com\/[a-z0-9]+$/i #http://imgur.com/OYLCtkH
			img_code = url.split('/')[-1]
			final_url = "http://i.imgur.com/#{img_code}.jpg"
		else
			puts "No handler for #{url}"
		end

		#existing_files = Array.new
		#existing_files << "9430ba4a" #imgur 404 image

		if final_url != ""
			domain = final_url.split('/')[2]
			path = final_url.split('/')[3..-1].join('/')
			puts "######### Downloading\nDomain: #{domain}\nPath: /#{path}\nTo: #{save_path}\nfinal_url: #{final_url}"
			FileUtils.mkpath(save_path) unless File.exists? save_path
			begin
				file_cont = fetch(final_url)
				if file_cont == ""
					puts "Nothing fetched from uri #{final_url}"
					return
				end
				puts "Saving file temporarily to #{save_path}tmp.jpg"
				puts "file_cont is #{file_cont.length} bytes"
			    open(save_path + "tmp.jpg", "wb") do |file|
			        file.write(file_cont)
			    end

			    new_filename = File.open(save_path + 'tmp.jpg') do |f| Zlib.crc32 f.read end.to_s(16) + '_' + sub.downcase
			    #if not existing_files.any do |f| f == new_filename end
					FileUtils.mv save_path + 'tmp.jpg', save_path + new_filename +'.jpg'
					puts "Saved as: #{save_path}#{new_filename}.jpg\n######### End"
					#existing_files << new_filename
				#end
				rescue SocketError
					warn "SocketError"
					#lalala
				rescue Net::HTTPServerException
					warn "HTTPServerException"
					#lalalaaaalalaa
				rescue OpenSSL::SSL::SSLError
					warn "SSLError"
					#tough luck!
				rescue Errno::ENOENT
					warn "ENOENT"
					#I wonder if this'll go :3
				rescue e
					warn e.inspect
					#I don't even care anymore :(
			end
		end
	end

	def fetch(uri_str, limit = 10)
		puts "Fetching: #{uri_str}"
		# You should choose a better exception.
		raise ArgumentError, 'too many HTTP redirects' if limit == 0

		uri = URI(uri_str)
		Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
			puts "Create uri"
			request = Net::HTTP::Get.new uri

			puts "Request uri"
			response = http.request request # Net::HTTPResponse object

			puts "Parse response"
			case response
				when Net::HTTPSuccess then
					puts "Fetch success"
					return response.body

				when Net::HTTPRedirection then
					location = response['location']
					puts "redirected to #{location}"
					puts "limit: #{limit}"
					fetch(location, limit - 1)

				else
					puts "Fetch failed"
					return ""
			end
		end
	end
end

Downloader.new.run