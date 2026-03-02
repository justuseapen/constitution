class AddProviderToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :provider, :integer, default: 0, null: false
  end
end
