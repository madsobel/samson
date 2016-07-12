require 'uri'

module SlackAppHelper
  def oauth_url(scopes)
    this_url = URI.encode url_for(only_path: false)
    scopes = URI.encode scopes
    "https://slack.com/oauth/authorize" \
      "?client_id=#{ENV['SLACK_CLIENT_ID']}" \
      "&redirect_uri=#{this_url}" \
      "&scope=#{scopes}"
  end
end
