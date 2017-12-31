require 'bundler'
Bundler.require

require "sinatra/reloader" if development?

set :views, File.dirname(__FILE__) + '/views'

enable :sessions

TwitterCredentials = Struct.new(:consumer_key, :consumer_secret)
twitter_credentials = TwitterCredentials.new(ENV["TWITTER_CONSUMER_KEY"], ENV["TWITTER_CONSUMER_SECRET"])

use OmniAuth::Builder do
  provider :twitter, twitter_credentials.consumer_key, twitter_credentials.consumer_secret
end

get '/' do
  erb :index
end

get '/links' do
  redirect("/") unless session[:authenticated]

  per_page = 200

  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = twitter_credentials.consumer_key
    config.consumer_secret     = twitter_credentials.consumer_secret
    config.access_token        = session[:token]
    config.access_token_secret = session[:secret]
  end

  @tweets = []
  tweets = client.home_timeline(count: per_page)
  @tweets += tweets.select do |tweet|
    tweet.uris? && tweet.uris.any? { |uri| !uri.expanded_url.to_s.include?("/status") }
  end

  erb :links
end

get '/auth/:name/callback' do
  auth = request.env['omniauth.auth']
  session[:authenticated] = true
  session[:avatar]        = auth.dig("info", "image")
  session[:screename]     = auth.dig("info", "nickname")
  session[:token]         = auth.dig("credentials",  "token")
  session[:secret]        = auth.dig("credentials", "secret")

  redirect '/links'
end

get '/logout' do
  session[:authenticated] = false
  redirect '/'
end
