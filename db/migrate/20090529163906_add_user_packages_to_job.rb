class AddUserPackagesToJob < ActiveRecord::Migration
  def self.up
    add_column :jobs, :user_packages, :text
  end

  def self.down
    remove_column :jobs, :user_packages
  end
end
