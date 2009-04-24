# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_clusterservice_session',
  :secret      => 'bb320dc47c387c682eaf1719f06281abc76bd43121cd82034f5c186563c2edf608a588fce186315de7ade137637044d140289bfb1ce58b6dd7d57f988836b14a'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
