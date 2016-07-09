class SlackIdentifier < ActiveRecord::Base
  belongs_to :user

  def self.app_token
    record = SlackIdentifier.find_by_user_id nil
    record.nil? ? nil : record.identifier
  end
end
