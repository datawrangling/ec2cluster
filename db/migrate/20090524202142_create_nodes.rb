class CreateNodes < ActiveRecord::Migration
  def self.up
    create_table :nodes do |t|
      t.references :job
      t.text :aws_image_id
      t.text :aws_instance_id
      t.text :aws_state
      t.text :dns_name
      t.text :ssh_key_name
      t.text :aws_groups
      t.text :private_dns_name
      t.text :aws_instance_type
      t.text :aws_launch_time
      t.text :aws_availability_zone
      t.boolean :is_configured

      t.timestamps
    end
  end

  def self.down
    drop_table :nodes
  end
end
