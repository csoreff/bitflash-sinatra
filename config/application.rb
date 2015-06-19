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
  conn.exec_params('INSERT INTO friends ( user_a, user_b, status ) VALUES
    ( $1, $2, $3 );', [session[:user_id], friend_user_id, 2])
end

def accept_friend_request(friendship_id)
  conn.exec_params('UPDATE friends SET status = 1 WHERE id = $1', [friendship_id])
end
