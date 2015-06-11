DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS friends;
DROP VIEW IF EXISTS friendships;

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  first_name varchar(30) NOT NULL,
  last_name varchar(30) NOT NULL,
  email varchar(100) NOT NULL,
  password varchar(100) NOT NULL,
  device_token varchar(255)
);

CREATE TABLE friends (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ default now(),
    user_a integer NOT NULL REFERENCES users,
    user_b integer NOT NULL REFERENCES users,
    status integer NOT NULL default 2
);

-- For listing friendships, a view:

CREATE VIEW friendships AS
    SELECT DISTINCT user_a, user_b FROM friends WHERE status = 1
    UNION
    SELECT DISTINCT user_b, user_a FROM friends WHERE status = 1;

-- You can use it like so:

-- INSERT INTO users ( name ) VALUES ( 'foo' );
-- INSERT INTO users ( name ) VALUES ( 'bar' );
-- INSERT INTO users ( name ) VALUES ( 'baz' );

-- SELECT * FROM users;
--  users_id | name
-- ----------+------
--         1 | foo
--         2 | bar
--         3 | baz

-- INSERT INTO FRIENDS ( user_a, user_b, status ) VALUES ( 1, 2, 1 );
-- INSERT INTO FRIENDS ( user_a, user_b, status ) VALUES ( 2, 1, 1 );
-- INSERT INTO FRIENDS ( user_a, user_b, status ) VALUES ( 1, 3, 1 );

-- SELECT * FROM friendships ORDER BY user_a, user_b;
--  user_a | user_b
-- --------+--------
--       1 |      2
--       1 |      3
--       2 |      1
--       3 |      1

-- SELECT a.first_name, a.last_name, b.first_name, b.last_name
--     FROM friendships
--     JOIN users a ON a.id = user_a
--     JOIN users b ON b.id = user_b
--     ORDER BY a.name, b.name;
--  name | name
-- ------+------
--  bar  | foo
--  baz  | foo
--  foo  | bar
--  foo  | baz

-- SELECT a.first_name AS user_first_name, a.last_name AS user_last_name,
--  b.first_name AS friend_first_name, b.last_name AS friend_last_name
--    FROM friendships
--    JOIN users a on a.id = user_a
--    JOIN users b on b.id = user_b
--    WHERE a.id = 1
--    ORDER BY a.first_name, b.first_name;