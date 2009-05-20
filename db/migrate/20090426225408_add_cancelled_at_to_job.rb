class AddCancelledAtToJob < ActiveRecord::Migration
  def self.up
    add_column :jobs, :cancelled_at, :datetime
  end

  def self.down
    remove_column :jobs, :cancelled_at
  end
end
