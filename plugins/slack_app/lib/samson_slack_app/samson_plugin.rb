module SamsonSlackApp
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :before_deploy do |deploy, _buddy|
  Rails.logger.debug(deploy)
  SlackMessage.new(deploy).deliver
end

Samson::Hooks.callback :after_deploy do |deploy, _buddy|
  Rails.logger.debug(deploy)
  SlackMessage.new(deploy).deliver
end
