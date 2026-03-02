class AddPrStatusToWorkOrderExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_order_executions, :pr_status, :integer
  end
end
