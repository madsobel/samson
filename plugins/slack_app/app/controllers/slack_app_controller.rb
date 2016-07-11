require 'slack'

class SlackAppController < ApplicationController
  skip_before_action :verify_authenticity_token, except: :oauth

  before_filter do
    @app_token = SlackIdentifier.app_token
    Slack.configure do |config|
      config.token = @app_token
    end
  end

  def oauth
    @need_to_connect_app = @app_token.nil?
    @need_to_connect_user = SlackIdentifier.find_by_user_id(current_user).nil?

    if params[:code]
      # Got an OAuth code, let's fetch our tokens
      resp = Slack.oauth_access client_id: ENV['SLACK_CLIENT_ID'],
                                client_secret: ENV['SLACK_CLIENT_SECRET'],
                                code: params[:code],
                                redirect_uri: url_for(only_path: false)
      if @need_to_connect_app
        @app_token = SlackIdentifier.create!(identifier: resp['access_token']).identifier
      end
      SlackIdentifier.create!(user_id: current_user.id, identifier: resp['user_id'])

      redirect_to
    end
  end

  def command
  end

  def interact
  end
end
