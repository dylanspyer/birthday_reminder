# frozen_string_literal: true

require 'pg'

# This is a class allows us to manipulate Postgresql databases related to the birthday app.
# Purpose is to persist user data.
class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: 'birthdays')
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  # Returns a hash with the `user_name` and `password` values from the `users` table
  def query_user_credentials_hash(username)
    sql = 'SELECT id, user_name, password FROM users WHERE user_name = $1;'
    result = query(sql, username)

    tuple = result.first

    return unless tuple

    user_id = tuple['id'].to_i
    { id: user_id, username: tuple['user_name'], password: tuple['password'] }
  end

  def create_new_user!(username, bcrypt_password)
    sql = 'INSERT INTO users (user_name, password) VALUES ($1, $2)'
    query(sql, username, bcrypt_password)
  end

  def query_user_id(username)
    sql = 'SELECT id FROM users WHERE user_name = $1'
    result = query(sql, username)
    result.first['id'].to_i
  end

  def delete_user_account!(username)
    sql = 'DELETE FROM users WHERE user_name = $1'
    query(sql, username)
  end

  def query_birthdays_for_month(user_id, month = Time.now.month)
    sql = 'SELECT * FROM birthdays WHERE EXTRACT(MONTH FROM birth_date) = $2 AND user_id = $1'
    result = query(sql, user_id, month)

    result.each.with_object({}) do |tuple, birthdays_in_month|
      _, _, day = tuple['birth_date'].split('-').map(&:to_i)
      name = tuple['birthday_name']
      birthdays_in_month[name] = day
    end
  end

  def create_new_birthday_person!(name, birth_date, interests, user_id)
    sql = 'INSERT INTO birthdays (birthday_name, birth_date, user_id) VALUES ($1, $2, $3);'
    query(sql, name, birth_date, user_id)

    sql_birthday_id = 'SELECT id FROM birthdays WHERE birthday_name = $1 AND birth_date = $2 AND user_id = $3'
    result = query(sql_birthday_id, name, birth_date, user_id)
    birthday_id = result[0]['id'].to_i

    interests.each do |interest|
      sql_interests = 'INSERT INTO interests (birthday_id, interest) VALUES ($1, $2);'
      query(sql_interests, birthday_id, interest)
    end
  end

  def query_all_birthdays_for_user(user_id)
    sql = 'SELECT id, birthday_name, birth_date FROM birthdays WHERE user_id = $1'
    result = query(sql, user_id)

    result.map do |tuple|
      tuple
    end
  end

  def birthday_person_exists?(birthday_person, user_id)
    sql = 'SELECT * FROM birthdays WHERE birthday_name = $1 AND user_id = $2'
    result = query(sql, birthday_person, user_id)

    tuple = result.first

    true if tuple
  end

  def query_birthday_person(birthday_person, user_id)
    sql = 'SELECT * FROM birthdays WHERE birthday_name = $1 AND user_id = $2'
    result = query(sql, birthday_person, user_id)

    result.first
  end

  # Need to get the `id` from the `birthdays` table given the birthday person's name and the user's id
  def query_birthday_person_interests(birthday_id)
    sql = "SELECT * FROM interests INNER JOIN birthdays ON birthdays.id = interests.birthday_id
          WHERE birthday_id = $1;"
    result = query(sql, birthday_id)

    result.map { |tuple| tuple['interest'] }
  end

  def delete_birthday_person!(name)
    sql = 'DELETE FROM birthdays WHERE birthday_name = $1'
    query(sql, name)
  end

  def create_new_interest!(_user_id, birthday_person_name, interest)
    sql = 'SELECT id FROM birthdays WHERE birthday_name = $1'
    result = query(sql, birthday_person_name)

    tuple = result.first
    birthday_id = tuple['id'].to_i

    sql_interests = 'INSERT INTO interests (birthday_id, interest) VALUES ($1, $2)'
    query(sql_interests, birthday_id, interest)
  end

  def user_name_exists?(username)
    sql = 'SELECT user_name FROM users'
    result = query(sql)

    result.map { |user| user['user_name'].downcase }.include?(username.downcase)
  end

  def query_birthday_id(birthday_name)
    sql = 'SELECT id FROM birthdays WHERE birthday_name = $1'
    result = query(sql, birthday_name)

    tuple = result.first
    tuple['id'].to_i
  end

  def delete_interest!(birthday_id, interest)
    sql = 'DELETE FROM interests WHERE birthday_id = $1 AND interest = $2'
    query(sql, birthday_id, interest)
  end
end
