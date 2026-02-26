class CreatePhases < ActiveRecord::Migration[8.1]
  def change
    create_table :phases do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, default: 0
      t.timestamps
    end
  end
end
