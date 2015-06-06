DROP TABLE IF EXISTS users;


CREATE TABLE users (
  user_id SERIAL,
  first_name varchar(30) NOT NULL,
  last_name varchar(30) NOT NULL,
  email varchar(100) NOT NULL,
  password varchar(100) NOT NULL,
  device_token varchar(255)
  PRIMARY KEY(user_id)
);
