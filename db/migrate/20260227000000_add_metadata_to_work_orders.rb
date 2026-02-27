class AddMetadataToWorkOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :work_orders, :metadata, :jsonb, default: {}
  end
end
