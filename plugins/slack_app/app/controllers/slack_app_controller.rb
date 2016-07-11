require 'slack'

class SlackAppController < ApplicationController
  skip_before_action :verify_authenticity_token, except: :oauth
  skip_around_action :login_user, except: :oauth

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
    # Interesting parts of the payload:
    # {
    #   "token"=>"NYFq6ZZzvcxp9skfxDQjfe6n", <-- verify against app token in ENV
    #   "user_id"=>"U0HAGH3AB", <-- look up Samson user using this
    #   "command"=>"/deploy",
    #   "text"=>"foo bar baz", <-- this is what to deploy
    #   "response_url"=>"https://hooks.slack.com/commands/T0HAGP0J2/58604540277/g0xd4K2KOsgL9zXwR4kEc0eL"
    #    ^^^^ This is how to respond later, we can also directly render some JSON
    # }
    return render json: 'ok' if params['ssl_check']
    deployer_id = SlackIdentifier.find_by_identifier params['user_id']
    deployer = User.find_by_id deployer_id.user_id
    return render json: unknown_user unless deployer
    render json: {text: "Yes m'lord"}
  end

  def interact
    # TODO
  end

  private

  def unknown_user
    {
      text: "Sorry, I don't recognize you. Perhaps you should visit " \
            "#{url_for action: :oauth, only_path: false} " \
            "to connect your account."
    }
  end
end
