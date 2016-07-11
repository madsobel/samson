class CreateDeployResponseUrlTable < ActiveRecord::Migration
  def change
    create_table :deploy_response_urls do |t|
      t.integer :deployment_id, null: false
      t.string :response_url, null: false

      t.timestamps
    end
  end
end
