require 'sinatra'
require 'pg'
require 'round'
require 'bcrypt'
require 'dotenv'
require 'rack-ssl-enforcer'
require 'pry'

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

def friend_request(friend_user_id)
  conn.exec_params("INSERT INTO friends ( user_a, user_b, status ) VALUES
    ( $1, $2, $3 );", [session[:user_id], friend_user_id, 2])
end

def accept_friend_request(friendship_id)
  conn.exec_params("UPDATE friends SET status = 1 WHERE id = $1", [friendship_id])
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
  device_token = query[0]['device_token']
  password = BCrypt::Password.new(correct_password)
  if password == params[:password]
    session[:email] = params[:email]
    session[:user_id] = query[0]['id']
    session[:device_token] = device_token
    redirect '/home'
  else
    erb :login
  end
end

get '/home' do
  client = Round.client
  client.authenticate_identify(api_token: ENV['ROUND_API_TOKEN'])
  @authenticated_user = client.authenticate_device(
    api_token: ENV['ROUND_API_TOKEN'],
    device_token: session[:device_token],
    email: session[:email]
  )
  get_friends_query = <<-SQL
    SELECT a.first_name AS user_first_name, a.last_name AS user_last_name,
      b.first_name AS friend_first_name, b.last_name AS friend_last_name
    FROM friendships
    JOIN users a on a.id = user_a
    JOIN users b on b.id = user_b
    WHERE a.id = $1
    ORDER BY a.first_name, b.first_name;
  SQL
  @friends_list = db_connection do |conn|
    conn.exec_params(get_friends_query, [session[:user_id]]).to_a
  end
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
