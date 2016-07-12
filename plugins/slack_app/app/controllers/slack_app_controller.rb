require 'slack'

class SlackAppController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:command, :interact]
  skip_around_action :login_user, except: :oauth

  before_action do
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
    check_slack_inputs! params
    render json: command_response
  end

  def interact
    # Interesting parts of the payload:
    # {
    #   "actions"=>[
    #     {"name"=>"one", "value"=>"one"} <-- which button the user clicked
    #   ],
    #   "callback_id"=>"deploy-123456", <-- maps to a deployment
    #   "user"=>{"id"=>"U0HAGH3AB", "name"=>"ben"}, <-- who clicked
    #   "action_ts"=>"1468259216.482422",
    #   "message_ts"=>"1468259019.000006", <-- need this to maybe update the message
    #   "response_url"=>"https://hooks.slack.com/actions/T0HAGP0J2/58691408951/iHdjN2zjX0dZ5rXyl84Otql7"
    # }
    payload = JSON.parse(params[:payload])
    check_slack_inputs!(payload)
    render json: interact_response(payload) # This replaces the original message
  end

  def check_slack_inputs!(params)
    if params[:ssl_check]
      render json: 'ok' if params['ssl_check']
      return false
    end
    raise "Invalid Slack token" unless params['token'] == ENV['SLACK_VERIFICATION_TOKEN']
  end

  def command_response
    # Interesting parts of params:
    # {
    #   "user_id"=>"U0HAGH3AB", <-- look up Samson user using this
    #   "command"=>"/deploy",
    #   "text"=>"foo bar baz", <-- this is what to deploy
    #   "response_url"=>"https://hooks.slack.com/commands/T0HAGP0J2/58604540277/g0xd4K2KOsgL9zXwR4kEc0eL"
    #    ^^^^ This is how to respond later, we can also directly render some JSON
    # }
    deployer_identifier = SlackIdentifier.find_by_identifier params['user_id']
    deployer = deployer_identifier.try(:user)
    return unknown_user unless deployer

    # Parse the command
    projectname, branchname, stagename = params['text'].match(/([^\s\/]+)(?:\/(\S+))?\s*(?:to\s+(.*))?/).captures

    # Sanity checks
    begin
      project = Project.find_by_param! projectname
    rescue ActiveRecord::RecordNotFound
      return unknown_project(projectname)
    end

    return unauthorized_deployer unless deployer.deployer_for?(project)

    begin
      stage = project.stages.find_by_param!(stagename || 'production')
    rescue ActiveRecord::RecordNotFound
      return unknown_stage(project, stagename)
    end

    deploy_service = DeployService.new(deployer)
    deploy = deploy_service.deploy!(stage, reference: branchname || 'master')
    DeployResponseUrl.create! deploy: deploy, response_url: params[:response_url]

    SlackMessage.new(deploy).message_body
  end

  def interact_response(payload)
    # This means someone clicked the "Approve" button in the channel
    deploy = Deploy.find_by_id payload['callback_id']
    return '_(Whoops, this deploy disappeared.)_' unless deploy

    # Is this user connected?
    buddy_identifier = SlackIdentifier.find_by_identifier payload['user']['id']
    buddy = buddy_identifier.try(:user)
    return {
      replace_original: false,
      text: unknown_user
    } unless buddy

    # Can this user approve the deployment?
    return {
      replace_original: false,
      text: "You can't approve your own deploys, silly!"
    } unless buddy != deploy.user
    return {
      replace_original: false,
      text: "It doesn't look like you have permissions to approve that deploy."
    } unless buddy.deployer_for?(deploy)

    # Buddy up
    deploy.confirm_buddy!(buddy)
    SlackMessage.new(deploy).message_body
  end

  def unknown_user
    "Sorry, I don't recognize you. Perhaps you should visit " \
    "#{url_for action: :oauth, only_path: false} " \
    "to connect your account."
  end

  def unknown_project(project)
    "Sorry, I don't know a project called `#{project}`. Try your project's permalink."
  end

  def unknown_stage(project, stagename)
    "Sorry, " \
    "<#{url_for controller: :projects, action: :show, id: project, only_path: false}|#{project.name}> " \
    "doesn't have a stage named `#{stagename}`."
  end

  def unauthorized_deployer(project)
    "Sorry, it doesn't look like you have permission to create a deployment" \
    "on `#{project}`."
  end
end
