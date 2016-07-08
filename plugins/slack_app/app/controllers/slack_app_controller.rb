class SlackAppController < ApplicationController
  skip_before_action :verify_authenticity_token

  def oauth
  end

  def command
  end

  def interact
  end
end
