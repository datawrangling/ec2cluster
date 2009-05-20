class RemoveSubmittedAtFromJob < ActiveRecord::Migration
  def self.up
    remove_column :jobs, :submitted_at
  end

  def self.down
    add_column :jobs, :submitted_at, :datetime
  end
end
