class CreateSlackAppTable < ActiveRecord::Migration
  def change
    create_table :slack_identifiers do |t|
      t.integer :user_id
      t.text :identifier, null: false

      t.timestamps
    end
  end
end
