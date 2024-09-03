-- One user has many birthday people to keep track of
-- One birthday person is associated with one user

-- One birthday person has many interests to keep track of
-- One interest has one birthday person associated with it

CREATE TABLE users (
  id serial PRIMARY KEY,
  user_name text NOT NULL UNIQUE,
  password text NOT NULL
);

CREATE TABLE birthdays (
  id serial PRIMARY KEY,
  birthday_name text NOT NULL,
  birth_date date NOT NULL,
  user_id integer NOT NULL REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE interests (
  id serial PRIMARY KEY,
  birthday_id integer NOT NULL REFERENCES birthdays(id) ON DELETE CASCADE,
  interest text NOT NULL
);

-- Sample data
INSERT INTO users (user_name, password) VALUES 
('dylan', '$2a$12$12ThvqrCBM/BlZ/tCkkdjeibnT9liC5w6kwcniq6n/selIZn..RbK'),
('matt', '$2a$12$6WVzzml181oIPtZeU9paNeFlOOPIoVxrsaUedyJusg8UVtZu3bOU.');

INSERT INTO birthdays (birthday_name, birth_date, user_id) VALUES
('matt spyer', '11/18/1981', 1),
('connor jaschen', '09/23/1996', 1),
('paige losack', '10/22/1996', 1),
('dad', '10/25/1958', 1),
('mom', '03/16/1961', 1),
('joe gomez', '12/06/1996', 1),
('jeff crofton', '04/13/1990', 1),
('rhonda hay', '03/09/1959', 1),
('jan baby test', '01/01/1999', 1);

INSERT INTO birthdays (birthday_name, birth_date, user_id) VALUES
('dylan spyer', '10/04/1992', 2);

INSERT INTO interests (birthday_id, interest) VALUES
(1, 'Video games'),
(1, 'Maverick'),
(1, 'Sports cards'),
(2, 'DND'),
(2, 'Jiu Jitsu'),
(3, 'EDM'),
(3, 'Turquoise'),
(3, 'Candles'),
(4, 'Music'),
(4, 'Drums'),
(6, 'Music'),
(6, 'Grappling'),
(9, 'MMA'),
(9, 'Piano'),
(9, 'Coding');
