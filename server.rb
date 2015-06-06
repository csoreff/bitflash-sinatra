require 'sinatra'
require 'pg'
require 'round'
require 'bcrypt'
require 'pry'
require 'dotenv'
require 'rack-ssl-enforcer'

Dotenv.load

use Rack::SslEnforcer
set :session_secret, ENV['SESSION_SECRET']

#Enable sinatra sessions
use Rack::Session::Cookie, :key => '_rack_session',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => settings.session_secret 

client = Round.client
api_token = ENV['ROUND_API_TOKEN']
client.authenticate_identify(api_token: api_token)

def db_connection
  begin
    connection = PG.connect(dbname: "bitflash")
    yield(connection)
  ensure
    connection.close
  end
end

def authenticate_user(api_token, device_token, email)
  full_user = client.authenticate_device(
            api_token: api_token,
            device_token: device_token,
            email: email
          )
end

get '/' do
  erb :index
end

get '/login' do
  erb :login
end

post '/login' do
  supplied_password = params[:password]
  correct_password = db_connection do |conn|
    conn.exec_params("select password from users where email = $1", [params[:email]]).to_a[0]['password']
  end
end

get '/register' do
  erb :register
end

post '/register' do
  first_name = params[:first_name]
  last_name = params[:last_name]
  email = params[:email]
  password = BCrypt::Password.create(params[:password])
  passphrase = params[:passphrase]
  device_name = params[:device_name]
  device_token = client.users.create(
                  first_name: first_name,
                  last_name: last_name,
                  email: email,
                  passphrase: passphrase,
                  device_name: device_name,
                  redirect_uri: 'http://something.com/user-device-approved'
                )
  conn.exec_params("INSERT INTO users VALUES ($1, $2, $3, $4, $5)", ['#{first_name}', '#{last_name}', '#{email}', '#{password}', '#{device_token}'])
end