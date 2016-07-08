Samson::Application .routes.draw do
  get '/slack/oauth', to: 'slack_app#oauth'
end
