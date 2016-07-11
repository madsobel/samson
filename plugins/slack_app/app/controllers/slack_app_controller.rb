require 'slack'

class SlackAppController < ApplicationController
  skip_before_action :verify_authenticity_token, except: :oauth
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
    #   "action_ts"=>"1468259216.482422", <-- need this to maybe update the message
    #   "message_ts"=>"1468259019.000006",
    #   "response_url"=>"https://hooks.slack.com/actions/T0HAGP0J2/58691408951/iHdjN2zjX0dZ5rXyl84Otql7"
    # }
    payload = JSON.parse(params[:payload])
    check_slack_inputs!(payload)
    render json: interact_response # This replaces the original message
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
    deployer = User.find_by_id deployer_identifier.try(:user_id)
    return unknown_user unless deployer

    # Parse the command
    projectname, branchname, stagename = params['text'].scan /(\S+)\/(\S+)\s*(?:to\s+(.*))?/
    puts projectname, branchname, stagename
    project = Project.find_by_name projectname
    return unknown_project(projectname) unless project.present?
    return unauthorized_deployer unless deployer.deployer_for?(project)
    stage = project.stages.find_by_param!(stagename || 'production')
    return unknown_stage(projectname, stagename) unless stage.present?

    # create deployment, associate deployment with response_url (need a new table)
    # This allows us to update the message 5 times in 30 minutes (should be enough)
    # -> suggested, started, finished/errored

  end

  def interact_response(payload)
    # This means someone clicked the "Approve" button in the channel
    # TODO
    # Is this user connected? If not, reply to them individually in a DM
    # Can this user approve the deployment? If not, tell them in a DM, or maybe inline?
    # Approve the
    'ok'
  end

  def message_body_for_deployment(deployment)
    # In progress -> "Deploying..."
    # Waiting for buddy: message with buttons
    # Done: ":tada:"
    {
      text: "Deployment requested",
      attachments: [
        {
          text: "Let's try this button thing.",
          fallback: "Whoops, attachments aren't working right now.",
          callback_id: 'deploy-123456',
          color: 'warning',
          attachment_type: 'default',
          actions: [
            button('Button :one:', 'one'),
            button('Button :two:', 'two', confirm: true)
          ]
        }
      ]
    }
  end

  def button(text, value, options = {})
    ret = {
      name: value,
      value: value,
      text: text,
      type: 'button'
    }
    if options[:confirm]
      ret['confirm'] = {
        title: 'Are you sure?',
        text: 'Confirm approval of this deployment.',
        ok_text: 'Confirm',
        dismiss_text: 'Never mind'
      }
    end
    ret
  end

  def unknown_user
    "Sorry, I don't recognize you. Perhaps you should visit " \
    "#{url_for action: :oauth, only_path: false} " \
    "to connect your account."
  end

  def unknown_project(name)
    "Sorry, I don't know a project called `#{name}`."
  end

  def unknown_stage(project, stage)
    "Sorry, `#{project}` doesn't have a stage named `#{stage}`."
  end

  def unauthorized_deployer(projectname)
    "Sorry, it doesn't look like you have permission to create a deployment" \
    "on `#{projectname}`."
  end
end
