require 'test_helper'

class WebserviceInteractionsTest < ActionController::IntegrationTest
  fixtures :all

  test "create_via_json" do
    assert_difference('Job.count') do
      post '/jobs/create',
        '{"job": {"name": "Job Posted via JSON", "number_of_instances": 12, "user_id": 2}}',
        {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
    end
  end
end
