Samson::Application .routes.draw do
  get '/slack_app/oauth', to: 'slack_app#oauth'
end
