class CreateJobs < ActiveRecord::Migration
  def self.up
    create_table :jobs do |t|
      t.string :name
      t.text :description
      t.integer :user_id
      t.string :instance_type
      t.integer :number_of_instances
      t.string :availability_zone
      t.text :input_files
      t.text :commands
      t.string :output_path
      t.text :output_files
      t.boolean :shutdown_after_complete
      t.string :master_ami_id
      t.string :worker_ami_id
      t.string :log_path
      t.string :keypair
      t.text :ebs_volumes
      t.string :mpi_version
      t.string :mpi_service_rest_url
      t.datetime :created_at
      t.datetime :submitted_at
      t.datetime :started_at
      t.datetime :updated_at
      t.datetime :finished_at
      t.string :state
      t.string :progress
      t.text :error_message
      t.string :master_security_group
      t.string :worker_security_group
      t.string :master_instance_id
      t.string :master_hostname
      t.string :master_public_hostname

      t.timestamps
    end
  end

  def self.down
    drop_table :jobs
  end
end
