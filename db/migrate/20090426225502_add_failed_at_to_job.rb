class AddFailedAtToJob < ActiveRecord::Migration
  def self.up
    add_column :jobs, :failed_at, :datetime
  end

  def self.down
    remove_column :jobs, :failed_at
  end
end
