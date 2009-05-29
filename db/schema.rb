# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20090529163906) do

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "jobs", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "user_id"
    t.string   "instance_type"
    t.integer  "number_of_instances"
    t.string   "availability_zone"
    t.text     "input_files"
    t.text     "commands"
    t.string   "output_path"
    t.text     "output_files"
    t.boolean  "shutdown_after_complete", :default => true
    t.string   "master_ami_id"
    t.string   "worker_ami_id"
    t.string   "log_path"
    t.string   "keypair"
    t.text     "ebs_volumes"
    t.string   "mpi_version"
    t.string   "mpi_service_rest_url"
    t.datetime "created_at"
    t.datetime "started_at"
    t.datetime "updated_at"
    t.datetime "finished_at"
    t.string   "state"
    t.string   "progress"
    t.text     "error_message"
    t.string   "master_security_group"
    t.string   "worker_security_group"
    t.string   "master_instance_id"
    t.string   "master_hostname"
    t.string   "master_public_hostname"
    t.datetime "cancelled_at"
    t.datetime "failed_at"
    t.text     "user_packages"
  end

  create_table "nodes", :force => true do |t|
    t.integer  "job_id"
    t.text     "aws_image_id"
    t.text     "aws_instance_id"
    t.text     "aws_state"
    t.text     "dns_name"
    t.text     "ssh_key_name"
    t.text     "aws_groups"
    t.text     "private_dns_name"
    t.text     "aws_instance_type"
    t.text     "aws_launch_time"
    t.text     "aws_availability_zone"
    t.boolean  "is_configured"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "nfs_mounted"
  end

end
