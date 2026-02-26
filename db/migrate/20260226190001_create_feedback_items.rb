class CreateFeedbackItems < ActiveRecord::Migration[8.1]
  def change
    create_table :feedback_items do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      t.string :source
      t.integer :category, default: 0
      t.integer :score
      t.integer :status, default: 0
      t.jsonb :technical_context, default: {}
      t.string :submitted_by_email
      t.timestamps
    end
    add_index :feedback_items, :category
    add_index :feedback_items, :status
  end
end
