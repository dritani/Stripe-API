require 'sinatra'
require 'stripe'
require 'dotenv'
require 'oauth2'
require 'json'
require 'encrypted_cookie'

Dotenv.load
Stripe.api_key = ENV['STRIPE_TEST_SECRET_KEY']

use Rack::Session::EncryptedCookie,
  :secret => 'replace_me_with_a_real_secret_key' # Actually use something secret here!

get '/' do
  status 200
  return "Great, your backend is set up. Now you can configure the Stripe example iOS apps to point here."
end

post '/charge' do
  authenticate!
  # Get the credit card details submitted by the form
  
  source = params[:source]
  # Create the charge on Stripe's servers - this will charge the user's card
  begin
    charge = Stripe::Charge.create(
      :amount => params[:amount], # this number should be in cents
      :currency => "usd",
      :customer => @customer.id,
      :source => source,
      :application_fee => params[:application_fee],
      :destination => params[:destination],
      :description => "Example Charge"
    )
  rescue Stripe::StripeError => e
    status 402
    return "Error creating charge: #{e.message}"
  end

  status 200
  return "Charge successfully created"
end

get '/customer' do
  if params.has_key?(:customer_id)
    session[:customer_id] = params[:customer_id]
  end
  
  authenticate!
  status 200
  content_type :json
  @customer.to_json
end

post '/customer/sources' do
  authenticate!
  source = params[:source]

  # Adds the token to the customer's sources
  begin
    @customer.sources.create({:source => source})
  rescue Stripe::StripeError => e
    status 402
    return "Error adding token to customer: #{e.message}"
  end

  status 200
  return "Successfully added source."
end

post '/customer/default_source' do
  authenticate!
  source = params[:source]

  # Sets the customer's default source
  begin
    @customer.default_source = source
    @customer.save
  rescue Stripe::StripeError => e
    status 402
    return "Error selecting default source: #{e.message}"
  end

  status 200
  return "Successfully selected default source."
end

get '/oauth/callback' do
    # Pull the authorization_code out of the response
    code = params[:code]

    # Make a request to the access_token_uri endpoint to get an access_token
    client_id = "ca_9NOj0hpFhVOmDtSoRStISkFgRZXAgcRu"

    options = {
      :site => 'https://connect.stripe.com',
      :authorize_url => '/oauth/authorize',
      :token_url => '/oauth/token'
    }

    client = OAuth2::Client.new(client_id, Stripe.api_key, options)



    @resp = client.auth_code.get_token(code, :params => {:scope => 'read_write'})
    @access_token = @resp.token


    # Use the access_token as you would a regular live-mode API key
    # TODO: Stripe logic
    #puts @resp.inspect
    return @resp.params["stripe_user_id"]
  end


get '/merchants' do
  authenticate!

  begin
    merchants = Stripe::Account.list(:limit => 3)
  rescue Stripe::StripeError => e
    status 402
    return "Error creating charge: #{e.message}"
  end

  status 200
  return merchants

end

def authenticate!
  # This code simulates "loading the Stripe customer for your current session".
  # Your own logic will likely look very different.
  return @customer if @customer
  if session.has_key?(:customer_id)
    customer_id = session[:customer_id]
    begin
      @customer = Stripe::Customer.retrieve(customer_id)
    rescue Stripe::InvalidRequestError
    end
  else
    begin
      @customer = Stripe::Customer.create(:description => "iOS SDK example customer")
    rescue Stripe::InvalidRequestError
    end
    session[:customer_id] = @customer.id
  end
  @customer
end

# This endpoint is used by the Obj-C example to complete a charge.
post '/charge_card' do
  # Get the credit card details submitted by the form
  token = params[:stripe_token]

  # Create the charge on Stripe's servers - this will charge the user's card
  begin
    charge = Stripe::Charge.create(
      :amount => params[:amount], # this number should be in cents
      :currency => "usd",
      :card => token,
      :description => "Example Charge"
    )
  rescue Stripe::StripeError => e
    status 402
    return "Error creating charge: #{e.message}"
  end

  status 200
  return "Charge successfully created"
end
