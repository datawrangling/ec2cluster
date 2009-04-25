require 'test_helper'

class WebserviceInteractionsTest < ActionController::IntegrationTest
  fixtures :all

  test "create_via_json" do
    assert_difference('Job.count') do
      post '/jobs/create',
        '{"job": {"name": "My Json MPI job", "description": "fdsfdfdsf", "user_id": 2, "number_of_instances": 12, "instance_type": "c1.medium",  "input_files": "s3://mybucket/input/genome.txt s3://myfastabucket/somedata.fasta", "commands": "bash runtandem.sh", "output_files": "myoutput.txt", "output_path": "S3://myoutputbucket/myrunsfolder"}}',
        {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
    end
  end
end
