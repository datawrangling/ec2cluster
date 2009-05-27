class AddNfsMountedToNode < ActiveRecord::Migration
  def self.up
    add_column :nodes, :nfs_mounted, :boolean
  end

  def self.down
    remove_column :nodes, :nfs_mounted
  end
end
