module SamsonSlackApp
  class Engine < Rails::Engine
  end
end

# To add in your own UI for a hook, e.g., for the stage edit page:
# - Create app/views/samson_slack_app/_my_fields.html.erb
# - Add this line to this file, note the lack of leading underscore and extension:
#   Samson::Hooks.view :stage_form, 'samson_slack_app/my_fields'


#Samson::Hooks.view :stage_form, '<view path>'

#Samson::Hooks.view :stage_show, '<view path>'

#Samson::Hooks.view :project_form, '<view path>'

#Samson::Hooks.view :deploy_group_show, '<view path>'

#Samson::Hooks.view :deploy_group_form, '<view path>'

#Samson::Hooks.view :deploy_group_table_header, '<view path>'

#Samson::Hooks.view :deploy_group_table_cell, '<view path>'

#Samson::Hooks.view :deploys_header, '<view path>'

#Samson::Hooks.view :deploy_tab_nav, '<view path>'

#Samson::Hooks.view :deploy_tab_body, '<view path>'

#Samson::Hooks.view :deploy_view, '<view path>'

#Samson::Hooks.view :deploy_form, '<view path>'

#Samson::Hooks.view :admin_menu, '<view path>'

#Samson::Hooks.view :project_tabs_view, '<view path>'


# Possible callbacks are listed below, delete any unused ones.

#Samson::Hooks.callback :stage_clone do
  # Do stuff in here
#end

#Samson::Hooks.callback :stage_permitted_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :deploy_permitted_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :project_permitted_params do
  # Do stuff in here
#end

# Samson::Hooks.callback :before_deploy do
  # Do stuff in here
# end

#Samson::Hooks.callback :after_deploy_setup do
  # Do stuff in here
#end

Samson::Hooks.callback :after_deploy do
  # Do stuff in here
end

#Samson::Hooks.callback :before_docker_build do
  # Do stuff in here
#end

#Samson::Hooks.callback :after_docker_build do
  # Do stuff in here
#end

#Samson::Hooks.callback :after_job_execution do
  # Do stuff in here
#end

#Samson::Hooks.callback :job_additional_vars do
  # Do stuff in here
#end

#Samson::Hooks.callback :deploy_group_permitted_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :edit_deploy_group do
  # Do stuff in here
#end
