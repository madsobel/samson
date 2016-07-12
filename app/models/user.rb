require 'soft_deletion'
require 'digest/md5'
require 'csv'

class User < ActiveRecord::Base
  include Searchable
  include HasRole

  TIME_FORMATS = ['local', 'utc', 'relative'].freeze

  has_soft_deletion default_scope: true

  has_paper_trail skip: [:updated_at, :created_at, :token]

  has_many :commands
  has_many :stars
  has_many :locks, dependent: :destroy
  has_many :user_project_roles, dependent: :destroy
  has_many :projects, through: :user_project_roles
  has_many :csv_exports, dependent: :destroy

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_token
  validates :time_format, inclusion: { in: TIME_FORMATS }

  scope :search, ->(query) {
    return self if query.blank?
    query = ActiveRecord::Base.send(:sanitize_sql_like, query)
    where("name LIKE ? OR email LIKE ?", "%#{query}%", "%#{query}%")
  }
  scope :with_role, -> (role_id, project_id) {
    joins("LEFT OUTER JOIN user_project_roles ON users.id = user_project_roles.user_id AND user_project_roles.project_id = #{project_id.to_i}"). # rubocop:disable Metrics/LineLength
      where('users.role_id >= ? OR user_project_roles.role_id >= ?', role_id, role_id)
  }

  def starred_project?(project)
    starred_project_ids.include?(project.id)
  end

  def starred_project_ids
    Rails.cache.fetch([:starred_projects_ids, id]) do
      stars.pluck(:project_id)
    end
  end

  # returns a scope
  def administrated_projects
    scope = Project.order(:name)
    unless admin?
      allowed = user_project_roles.where(role_id: Role::ADMIN.id).pluck(:project_id)
      scope = scope.where(id: allowed)
    end
    scope
  end

  def self.to_csv(
    inherited: false, deleted: false, project_id: nil, user_id: nil,
    datetime: (Time.now.strftime "%Y%m%d_%H%M")
  )
    inherited = true if project_id || user_id
    users = if user_id.nil?
      deleted ? User.unscoped.order(:id) : User.order(:id)
    else
      user_id && User.unscoped.where(id: user_id)
    end
    if inherited
      permissions_projects = project_id ? Project.where(id: project_id) : Project.all
    end
    total = permissions_count(project_id, inherited, users, permissions_projects)
    summary = ["-", "Generated At", datetime, "Users", users.count.to_s, "Total entries", total.to_s]
    options_applied = [
      "-", "Options",
      {
        inherited: inherited,
        deleted: deleted,
        project_id: project_id,
        user_id: user_id
      }.to_json
    ]

    CSV.generate do |csv|
      csv << ["id", "name", "email", "projectiD", "project", "role", "deleted at"]
      users.find_each do |user|
        csv << user.csv_line unless project_id
        if inherited
          permissions_projects.find_each { |project| csv << user.csv_line(project) }
        else
          UserProjectRole.where(user_id: user.id).joins(:project).find_each do |user_project_role|
            csv << user.csv_line(user_project_role.project)
          end
        end
      end
      csv << summary
      csv << options_applied
    end
  end

  def csv_line(project = nil)
    if project
      [id, name, email, project.id, project.name, effective_project_role(project), deleted_at]
    else
      [id, name, email, "", "SYSTEM", role.name, deleted_at]
    end
  end

  def self.create_or_update_from_hash(hash)
    user = User.where(external_id: hash[:external_id].to_s).first || User.new

    # attributes are always a string hash
    attributes = user.attributes.merge(hash.stringify_keys) do |key, old, new|
      if key == 'role_id'
        if !User.exists? # first user will be the super admin
          Role::SUPER_ADMIN.id
        elsif new && (user.new_record? || new >= old)
          new
        else
          old
        end
      else
        old.presence || new
      end
    end

    user.attributes = attributes
    user.save
    user
  end

  def name
    super.presence || email
  end

  def name_and_email
    "#{name} (#{email})"
  end

  def gravatar_url
    md5 = email.blank? ? "default" : Digest::MD5.hexdigest(email)
    "https://www.gravatar.com/avatar/#{md5}"
  end

  def admin_for?(project)
    admin? || !!project_role_for(project).try(:admin?)
  end

  def deployer_for?(project)
    deployer? || !!project_role_for(project).try(:deployer?)
  end

  def project_role_for(project)
    user_project_roles.find_by(project: project)
  end

  def effective_project_role(project)
    project_role = project_role_for(project)
    if role_id == Role::SUPER_ADMIN.id
      Role::ADMIN.name
    else
      role_id >= (project_role.try(:role_id) || 0) ? role.name : project_role.role.name
    end
  end

  def record_project_role_change
    record_update true
  end

  private

  # overwrites papertrail to record script
  def object_attrs_for_paper_trail(attributes)
    roles = user_project_roles.map { |upr| [upr.project.permalink, upr.role_id] }.to_h
    super(attributes.merge('project_roles' => roles))
  end

  def set_token
    self.token = SecureRandom.hex
  end

  private_class_method def self.permissions_count(project_id, inherited, users, permissions_projects = [])
    if inherited
      project_id ? users.count : (1 + permissions_projects.count) * users.count
    else
      users.count + UserProjectRole.joins(:user, :project).count
    end
  end
end
