class CreateAgentConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_conversations do |t|
      t.string :conversable_type, null: false
      t.bigint :conversable_id, null: false
      t.references :user, null: false, foreign_key: true
      t.string :model_provider
      t.string :model_name
      t.timestamps
    end
    add_index :agent_conversations, [:conversable_type, :conversable_id]
  end
end
