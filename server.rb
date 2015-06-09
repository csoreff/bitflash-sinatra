require 'sinatra'
require 'pg'
require 'round'
require 'bcrypt'
require 'dotenv'
require 'rack-ssl-enforcer'

Dotenv.load

configure :development do
  set :session_secret, ENV['SESSION_SECRET']
  use Rack::Session::Cookie, key: '_rack_session',
                             path: '/',
                             expire_after: 2_592_000, # In seconds
                             secret: settings.session_secret
  set :db_config, dbname: 'bitflash'
end

configure :production do
  uri = URI.parse(ENV['DATABASE_URL'])
  use Rack::SslEnforcer
  set :session_secret, ENV['SESSION_SECRET']

  # Enable sinatra sessions
  use Rack::Session::Cookie, key: '_rack_session',
                             path: '/',
                             expire_after: 2_592_000, # In seconds
                             secret: settings.session_secret
  set :db_config,
      host: uri.host,
      port: uri.port,
      dbname: uri.path.delete('/'),
      user: uri.user,
      password: uri.password
end

def db_connection
  connection = PG.connect(settings.db_config)
  yield(connection)
ensure
  connection.close
end

get '/' do
  erb :index
end

get '/login' do
  erb :login
end

post '/login' do
  query = db_connection do |conn|
    conn.exec_params('select password, id, device_token from users where email
      =$1', [params[:email]]).to_a
  end
  correct_password = query[0]['password']
  user_id = query[0]['id']
  device_token = query[0]['device_token']
  password = BCrypt::Password.new(correct_password)
  if password == params[:password]
    session[:email] = params[:email]
    session[:user_id] = user_id
    session[:device_token] = device_token
    redirect '/home'
  else
    erb :login
  end
end

get '/home' do
  client = Round.client
  client.authenticate_identify(api_token: ENV['ROUND_API_TOKEN'])
  user = client.authenticate_device(
    api_token: ENV['ROUND_API_TOKEN'],
    device_token: session[:device_token],
    email: session[:email]
  )
  erb :home
end

get '/register' do
  erb :register
end

post '/register' do
  client = Round.client
  first_name = params[:first_name]
  last_name = params[:last_name]
  email = params[:email]
  password = BCrypt::Password.create(params[:password])
  passphrase = params[:passphrase]
  device_name = params[:device_name]
  client.authenticate_identify(api_token: ENV['ROUND_API_TOKEN'])
  device_token = client.users.create(
    first_name: first_name,
    last_name: last_name,
    email: email,
    passphrase: passphrase,
    device_name: device_name,
    redirect_uri: 'https://bitflash.herokuapp.com'
  )
  query = <<-SQL
  INSERT INTO users (first_name, last_name, email, password, device_token)
  VALUES ($1, $2, $3, $4, $5)
  SQL
  values = [first_name, last_name, email, password, device_token]
  db_connection do |conn|
    conn.exec_params(query, values)
  end
  erb :index
end
