require 'sinatra'
require './feeders'
require 'json'
require 'open-uri'
require 'mail'

# Reload if in development mode
require 'sinatra/reloader' if development?

set :success, 'success'
set :auth_error, 'auth_error'
set :does_not_exist, 'does_not_exist'
set :already_exists, 'already_exists'
set :no_img, 'no_img_url'
set :not_found_error, 'not_found'
set :common_error, 'something_happened'

# for development
configure :development do
	DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/feeders.db")
	# DataMapper.setup(:donations, "sqlite3://#{Dir.pwd}/donations.db")
end

# DB for production
configure :production do
	DataMapper.setup(:default, ENV['DATABASE_URL'])
	# DataMapper.setup(:donations, ENV['DATABASE_URL'])
end

get '/' do
	'Using SendGrid to send emails to admin of this application'
end

# Retrieve User Data
get '/:email' do
	user_data = get_user(params[:email].to_s)

	if user_data.nil?
		return settings.does_not_exist
	end

	content_type :json
	user_data.to_json
end

# Sign in
post '/login/:email' do
	user_data = get_user(params[:email].to_s)

	if user_data.nil?
		return settings.does_not_exist
	end

	content_type :json
	user_data.to_json
end

# Sign up
post '/feeders/:email/:name/:phone/:state/:address' do

	user_data = get_user(params[:email].to_s)

	if user_data.nil?
		feeder = Feeders.new

		feeder.email = params[:email].to_s
		feeder.name = params[:name].to_s
		feeder.phone = params[:phone].to_s
		feeder.state = params[:state].to_s
		feeder.address = params[:address].to_s
		# feeder.pincode = params[:pincode.to_s]
		feeder.times_fed = 0

		feeder.save
		
		content_type :json
		{
			:email => feeder.email,
			:name => feeder.name,
			:phone => feeder.phone,
			:state => feeder.state,
			:address => feeder.address,
			:times_fed => feeder.times_fed
		}.to_json
	else
		return settings.already_exists	
	end
end

# Make donation
post '/donation/:email/:description/:time' do

	user_data = get_user(params[:email].to_s)

	if user_data.nil?
		return settings.does_not_exist
	end

	email = params[:email].to_s
	description = params[:description].to_s
	time = params[:time].to_s

	# Additional parameters passed
	url = params[:url]
	location = params[:location]
	foodtype = params[:foodtype]
	packing = params[:packing]
	foodfor = params[:foodfor]

	if url.nil?
		return settings.no_img
	end

	food_info = "Description: " + description + "Foodtype: " + foodtype + 
		"Packaging: " + packing + "Food for: " + foodfor + 
		"Preferable pickup time: " + time

	if !location.nil?
		food_info = food_info + "Location: " + location
	end

	# Downloads file to attach it later
	File.open('tmp/image.png', 'wb') do |fo|
		fo.write open(url).read 
	end

	status = send_mail(email, food_info, location)

	return status
end

# All errors
error do
	return settings.common_error
end

# Not Found error
not_found do
	return settings.not_found_error
end



helpers do

	def get_user(email)
		feeder = Feeders.first(:email => email)
		if feeder.nil?
			return nil
		end
		user_data = {
			:email => feeder.email,
			:name => feeder.name,
			:phone => feeder.phone,
			:state => feeder.state,
			:address => feeder.address,
			# :pincode => feeder.pincode,
			:times_fed => feeder.times_fed
		}
		return user_data
	end

	def send_mail (email, food_info, location)

		feeder = Feeders.first(:email => email)

		if feeder.nil?
			return settings.does_not_exist
		end

		feeder.times_fed += 1
		feeder.save

		# Create message with donation data
		donation_msg = "Email: " + email + "\nName: " + feeder.name + 
			"\nPhone: " + feeder.phone + "\nState: " + feeder.state + 
			# "\nPin-Code: " + feeder.pincode
			+ "Times Donated:" + feeder.times_fed + "\n" + food_info

			if location.nil?
				donation_msg = donation_msg + "\nAddress: " + feeder.address
			end


		# Regular Mail
		options = { :address				=> "smtp.gmail.com",
					:port					=> 587,
					:domain					=> 'your.host.name',
					:user_name				=> 'pccestuff@gmail.com',
					:password				=> '',
					:authentication			=> 'plain',
					:enable_starttls_auto	=> true  }


		Mail.defaults do
			delivery_method :smtp, options
		end

		Mail.deliver do
			to 'hhlda@slipry.net' #'aldrichm69@gmail.com'
			from "donator@xyz.com"
			subject 'Food Donation'
			body donation_msg
			add_file "#{Dir.pwd}/tmp/image.png"
		end

		
		# SendGrid Email

		# Mail.defaults do
		# 	delivery_method :smtp, {
		# 		:address => 'smtp.sendgrid.net',
		# 		:port => '587',
		# 		:domain => 'heroku.com',
		# 		:user_name => ENV['SENDGRID_USERNAME'],
		# 		:password => ENV['SENDGRID_PASSWORD'],
		# 		:authentication => :plain,
		# 		:enable_starttls_auto => true
		# 	}
		# end

		# Mail.deliver do
		# 	to 'example@example.com'
		# 	from 'sender@example.comt'
		# 	subject 'Donation'
		# 	body donation_msg
		# 	add_file "#{Dir.pwd}/tmp/image.png"
		# end

		return settings.success
	end
end