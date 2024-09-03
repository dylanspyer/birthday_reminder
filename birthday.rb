# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'bcrypt'
require 'rubocop'

require_relative 'database_persistence'

MONTH_NUM_HASH = {
  'January' => 1,
  'February' => 2,
  'March' => 3,
  'April' => 4,
  'May' => 5,
  'June' => 6,
  'July' => 7,
  'August' => 8,
  'September' => 9,
  'October' => 10,
  'November' => 11,
  'December' => 12
}.freeze

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, escape_html: true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

before do
  @storage = DatabasePersistence.new(logger)
end

# Authenticates the user. Returns `true` if username and password match what is in the `users` database.
def valid_user_credentials?(username, password)
  user_credentials = @storage.query_user_credentials_hash(username)

  if user_credentials
    bcrypt_password = BCrypt::Password.new(user_credentials[:password])
    bcrypt_password == password
  else
    false
  end
end

# Mutates the session to add the username and user id.
def set_session_credentials!(username, user_id)
  session[:username] = username
  session[:user_id] = user_id
end

def error_for_sign_up?(potential_user_name, potential_password, confirm_potential_password)
  true if potential_user_name.empty? ||
          !valid_username?(potential_user_name) ||
          potential_password != confirm_potential_password ||
          @storage.user_name_exists?(potential_user_name) ||
          potential_password.empty?
end

def set_sign_up_error_messages(potential_username, potential_password, confirm_potential_password)
  error_msgs = []
  error_msgs << 'Name is required' if potential_username.empty?
  error_msgs << 'Username must be between 1 and 100 characters and no spaces' unless valid_username?(potential_username)
  error_msgs << 'Passwords must match' if potential_password != confirm_potential_password
  if @storage.user_name_exists?(potential_username)
    error_msgs << "#{potential_username} already exists - please try a different name"
  end
  error_msgs << 'Password cannot be empty' if potential_password.empty? || confirm_potential_password.empty?
  session[:message] = error_msgs.join(', ')
end

# Checks if the user is accessing resources specific to them (cannot access another user's data).
def check_credentials
  # Check if the session username is the same as the parameter username
  return unless session[:username] != params[:username]

  # If not, save the path requested so we can route the user to it after they sign in
  session[:requested_path] = @env['REQUEST_PATH']
  session[:message] = "You must be logged in as #{params[:username]} to do that."
  redirect '/sign_in'
end

def error_for_add_birthday?(birthday_name, birth_date, interests)
  true if birth_date.empty? ||
          !valid_birthday_name?(birthday_name) ||
          duplicate_birthday_person?(birthday_name) ||
          !valid_interests?(interests)
end

def set_birthday_error_messages(birthday_name, birth_date, interests)
  error_messages = []
  error_messages << 'Name is required' if birthday_name.empty?
  error_messages << 'Date is required' if birth_date.empty?
  error_messages << 'Name cannot contain / or \\' if birthday_name.match(%r{[/\\]})
  unless valid_interests?(interests)
    error_messages << 'Interest must be between 1 and 100 characters and cannot be only white space.'
  end
  error_messages << "#{birthday_name.capitalize} already exists." if duplicate_birthday_person?(birthday_name)

  session[:message] = error_messages.join(', ')
end

def duplicate_birthday_person?(name)
  birthdays = @storage.query_all_birthdays_for_user(session[:user_id])
  birthdays.each do |birthday|
    return true if birthday['birthday_name'].downcase == name.downcase
  end
  false
end

def create_new_birthday_person_hash(params)
  interests = params.fetch_values(:interest1, :interest2, :interest3).reject(&:empty?)

  {
    birthday_name: params[:birthday_name].split.map(&:downcase).join(' '),
    birthday_date: params[:birthday_date],
    interests:
  }
end

# Checks if username is valid input (not empty and between 1 and 100 characters)
def valid_username?(username)
  return false if username.include?(' ')

  (1..100).cover?(username.size)
end

# Checks if interest or birthday names are valid (they can both include spaces, unlike usernames)
def valid_birthday_name?(birthday_name)
  processed_birthday_name = birthday_name.strip
  (1..100).cover?(processed_birthday_name.size) && !processed_birthday_name.match(%r{[/\\]})
end

def valid_interest?(interest)
  processed_interest = interest.strip
  (1..100).cover?(processed_interest.size)
end

def valid_interests?(interests_array)
  interests_array.all? { |interest| valid_interest?(interest) }
end

def paginate(items, max_items_per_page, &block)
  items.each_slice(max_items_per_page).with_index(1, &block)
end

helpers do
  def display_formatted_name(name)
    name.split.map(&:capitalize).join(' ')
  end

  def sort_interests_alphabetically(interests)
    interests.sort_by(&:downcase)
  end

  # Loop through an array of birthday hashes. Parse hash and yield month, name, and previous month to a passed block.
  def parse_birthday_array_of_hashes(birthdays)
    birthdays.each.with_index do |birthday, index|
      previous_month = if index.zero?
                         nil
                       else
                         MONTH_NUM_HASH.key(Date.parse(birthdays[index - 1]['birth_date']).month)
                       end
      birthday_month = MONTH_NUM_HASH.key(Date.parse(birthdays[index]['birth_date']).month)

      yield birthday_month, birthday['birthday_name'], previous_month
    end
  end

  def days_in_month(month = Date.today.month, year = Date.today.year)
    first_day_of_month = Date.new(year, month)

    (first_day_of_month.next_month - first_day_of_month).to_i
  end

  def first_day_of_month(year, month)
    first_day_of_month = Date.new(year, month)
    first_day_of_month.wday
  end
end

# rubocop:disable Layout/LineLength: Line is too long.
# URL SCHEME
# GET  /                                                 -> view the index if not logged in, view the user home page if logged in
# GET  /sign_in                                          -> view the sign in page
# POST /sign_in                                          -> log in as a user
# POST /sign_out                                         -> sign out a user
# GET  /sign_up                                          -> view the sign up page
# POST /sign_up                                          -> create a new user
# GET  /:username/home                                   -> view user's home page
# GET  /:username/add_birthday                           -> view the add birthday profile page
# POST /:username/add_birthday                           -> create a new birthday profile page
# GET  /:username/:birthday_person                       -> get the birthday person's profile page
# POST /:username/:birthday_person/delete                -> delete a birthday person's profile page
# POST /:username/:birthday_person/add_interest          -> add an interest to a birthday person
# POST /:username/:birthday_person/delete_interest       -> delete an interest from a birthday person
# GET  /:username/:month/:year/calendar                  -> view birthday calendar for a specific month and year
# GET  /redirect_to_selected_calendar                    -> takes inputs from the form submission which specifies which month and year calendar to generate, renders appropriate calendar
# GET  /:username/all_birthdays                          -> redirects to the first page of all the birthdays (5 birthdays per page)
# GET  /:username/all_birthdays/:page_number             -> view an index of all the birthday profiles sorted by month and then alphabetical
# GET  /favicon.ico                                      -> redirects to the requested path (this is a sinatra quirk, fixing a bug)
# rubocop:enable Layout/LineLength: Line is too long.

# View the user home page if signed in, view the index page (sign in / sign up page) otherewise
get '/' do
  if session[:username]
    redirect "/#{session[:username]}/home"
  else
    erb :index
  end
end

# View the sign in form.
get '/sign_in' do
  erb :sign_in
end

# Validates the user credentials and routes the user appropriately or gives an error msg if incorrect credentials
post '/sign_in' do
  attempted_username = params[:username].downcase
  attempted_password = params[:password]

  if valid_user_credentials?(attempted_username, attempted_password) && session[:requested_path]
    user_credentials = @storage.query_user_credentials_hash(attempted_username)
    user_id = user_credentials[:id]
    set_session_credentials!(attempted_username, user_id)

    session[:message] = "Welcome, #{display_formatted_name(attempted_username)}!"
    redirect session.delete(:requested_path)
  elsif valid_user_credentials?(attempted_username, attempted_password)
    user_credentials = @storage.query_user_credentials_hash(attempted_username)
    user_id = user_credentials[:id]
    set_session_credentials!(attempted_username, user_id)

    session[:message] = "Welcome, #{display_formatted_name(attempted_username)}!"
    redirect "#{attempted_username}/home"
  else
    session[:message] = 'Invalid username or password. Please try again.'
    erb :sign_in
  end
end

# View the sign up form
get '/sign_up' do
  erb :sign_up
end

# Submit the sign up form to create a new user profile
post '/sign_up' do
  potential_user_name = params['username'].downcase
  potential_password = params['password']
  confirm_potential_password = params['confirm_password']

  if error_for_sign_up?(potential_user_name, potential_password, confirm_potential_password)
    set_sign_up_error_messages(potential_user_name, potential_password, confirm_potential_password)
    erb :sign_up
  else
    bcrypt_password = BCrypt::Password.create(potential_password)
    @storage.create_new_user!(potential_user_name, bcrypt_password)
    user_id = @storage.query_user_id(potential_user_name)

    set_session_credentials!(potential_user_name, user_id)

    redirect "#{potential_user_name}/home"
  end
end

# Delete a user account
post '/:username/delete_account' do
  check_credentials

  username = params[:username].downcase

  @storage.delete_user_account!(username)
  session[:message] = "#{session.delete(:username)} has been deleted."
  session.delete(:requested_path)

  redirect '/'
end

# Signs a user out and redirects to the index
post '/sign_out' do
  session.delete(:username)

  redirect '/'
end

# Renders the user's home page. Displays possible user actions (see all birthdays, add a birthday...)
get '/:username/home' do
  check_credentials

  @username = params[:username]
  @current_month = MONTH_NUM_HASH.key(Time.now.month)
  @current_year = Time.now.year

  erb :user_profile
end

# Uses parameters submitted through the "choose month and year" form to redirect to a specific month and year calendar
get '/redirect_to_selected_calendar' do
  username = session[:username]
  month = params[:month]
  year = params[:year].to_i

  if year.positive?
    redirect "/#{username}/#{month}/#{year}/calendar"
  else
    session[:message] = 'Please enter a valid year.'
    redirect "/#{username}/home"
  end
end

# Renders the user's birthday calendar. Displays a calendar with all birthdays.
get '/:username/:month/:year/calendar' do
  check_credentials

  user_id = session[:user_id]
  @month = params[:month].capitalize
  @year = params[:year].to_i
  @this_month_birthdays = @storage.query_birthdays_for_month(user_id, MONTH_NUM_HASH[params[:month]])

  erb :calendar
end

# Renders the add birthday form
get '/:username/add_birthday' do
  check_credentials

  @username = params[:username]

  erb :add_birthday
end

# Submits a new birthday
post '/:username/add_birthday' do
  check_credentials

  @username = params[:username].downcase
  @birthday_name = params[:birthday_name].downcase.gsub(/\s+/, ' ').strip
  @birth_date = params[:birthday_date]

  new_birthday_person_hash = create_new_birthday_person_hash(params)
  name = new_birthday_person_hash[:birthday_name]
  birth_date = new_birthday_person_hash[:birthday_date]
  interests = new_birthday_person_hash[:interests]
  user_id = session[:user_id]

  if error_for_add_birthday?(@birthday_name, @birth_date, interests)
    status 422
    set_birthday_error_messages(@birthday_name, @birth_date, interests)
    erb :add_birthday
  else

    @storage.create_new_birthday_person!(name, birth_date, interests, user_id)
    session[:message] = "You successfully added #{display_formatted_name(@birthday_name)}!"
    encoded_uri = URI.encode_uri_component(@birthday_name)
    redirect "/#{@username}/#{encoded_uri}"
  end
end

# Redirects user to the first page if they use `all_birthdays` route without a page number
get '/:username/all_birthdays' do
  check_credentials

  username = params[:username]

  redirect "/#{username}/all_birthdays/1"
end

# Fix a bug that requests favicon.ico by redirecting to the requested path
get '/favicon.ico' do
  redirect session[:requested_path]
end

# View an index of all birthdays being tracked for a specific user
get '/:username/all_birthdays/:page_number' do
  check_credentials

  user_id = session[:user_id]
  @current_page = params[:page_number].to_i
  @previous_page = @current_page - 1
  @next_page = @current_page + 1
  @username = params[:username]

  birthdays = @storage.query_all_birthdays_for_user(user_id)
  sorted_birthdays = birthdays.sort_by do |birthday|
    month = Date.parse(birthday['birth_date']).month
    day = Date.parse(birthday['birth_date']).day
    [month, day]
  end

  @pages = []

  paginate(sorted_birthdays, 5) do |page_contents, page_number|
    @birthdays = page_contents if page_number == @current_page
    @pages << page_number
    @highest_page = page_number
  end

  if !@highest_page
    session[:message] = 'You are not keeping track of any birthdays! Please add some first.'
    redirect "#{@username}/home"
  elsif @current_page.positive? && @current_page <= @highest_page
    erb :all_birthdays
  else
    session[:message] =
      "#{@current_page} is not a valid page. Please try a page less than #{@highest_page} and greater than 0."
    redirect "#{@username}/all_birthdays"
  end
end

# Redirect to the user's homepage if the user doesn't follow the correct url scheme
get '/:username' do
  redirect "#{params[:username]}/home"
end

# Birthday profile
get '/:username/:birthday_person' do
  check_credentials

  @username = params[:username]
  user_id = session[:user_id]
  @birthday_person = params[:birthday_person].downcase

  if @storage.birthday_person_exists?(@birthday_person, user_id)
    birthday_person_details = @storage.query_birthday_person(@birthday_person, user_id)

    @name = birthday_person_details['birthday_name']
    @birthdate = birthday_person_details['birth_date']
    birthday_id = birthday_person_details['id']

    @interests_array = @storage.query_birthday_person_interests(birthday_id)

    session[:month] = MONTH_NUM_HASH.key(Date.parse(@birthdate).month)
    session[:year] = Date.today.year

    erb :birthday_profile
  else
    session[:message] = "#{display_formatted_name(@birthday_person)} does not exist. Please try adding them!"
    redirect "#{@username}/home"
  end
end

# Delete a birthday person
post '/:username/:birthday_person/delete' do
  check_credentials

  @storage.delete_birthday_person!(params[:birthday_person])
  session[:message] = "#{display_formatted_name(params[:birthday_person])} has been deleted."
  redirect '/'
end

# Add a new interest to a birthday person
post '/:username/:birthday_person/add_interest' do
  check_credentials

  username = params[:username]
  user_id = session[:user_id]
  birthday_person_name = params['birthday_person']
  interest = params['new_interest']

  if valid_interest?(interest)
    @storage.create_new_interest!(user_id, birthday_person_name, interest)
    session[:message] = "Successfully added an interest to #{display_formatted_name(birthday_person_name)}."
  else
    session[:message] = 'Interest must be between 1 and 100 characters and cannot be only white space.'
    session[:invalid_interest] = interest
  end
  redirect "/#{username}/#{birthday_person_name}"
end

# Delete an interest
post '/:username/:birthday_person/delete_interest' do
  check_credentials

  username = params[:username]
  interest_to_be_deleted = params[:delete_interest]
  birthday_name = params[:birthday_person]
  birthday_id = @storage.query_birthday_id(birthday_name)

  @storage.delete_interest!(birthday_id, interest_to_be_deleted)

  redirect "/#{username}/#{birthday_name}"
end
