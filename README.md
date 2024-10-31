How to install, configure, and run the application:

- Unzip the compressed application file
- Change directories in the terminal to the uncompressed project file using `cd birthday_project_final`
- Create the required database by using `createdb birthdays` in the terminal
- Create tables and pipe in sample data using `psql -d birthdays < schema.sql` in the terminal
- Install the gems using `bundle install`
- Run the application using `bundle exec ruby birthday.rb`
- Navigate to the appropriate URL based on your specific port number, for example `localhost:4567`
- You can then log into either of the two sample users with the following credentials:
  - username: dylan
  - password: secret
  - username: matt
  - password: secret

The version of Ruby you used to run this application:

- ruby '3.2.2'

The browser (including version number) that you used to test this application:

- Google Chrome
- Version 118.0.5993.88 (Official Build) (arm64)

The version of PostgreSQL you used to create any databases:
-psql (14.8 (Homebrew))
