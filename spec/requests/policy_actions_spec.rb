#
# REST API Request Tests - Policy Actions
#
# Policy Action primary collection:
#   /api/policy_actions
#
# Policy Action subcollection:
#   /api/policies/:id/policy_actions
#
describe "Policy Actions API" do
  let(:miq_action_guid_list) { MiqAction.pluck(:guid) }

  def create_actions(count)
    1.upto(count) do |i|
      FactoryBot.create(:miq_action, :name => "custom_action_#{i}", :description => "Custom Action #{i}")
    end
  end

  context "Policy Action collection" do
    it "query invalid action" do
      api_basic_authorize action_identifier(:policy_actions, :read, :resource_actions, :get)

      get api_policy_action_url(nil, 999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "query policy actions with no actions defined" do
      api_basic_authorize collection_action_identifier(:policy_actions, :read, :get)

      get api_policy_actions_url

      expect_empty_query_result(:policy_actions)
    end

    it "query policy actions" do
      api_basic_authorize collection_action_identifier(:policy_actions, :read, :get)
      create_actions(4)

      get api_policy_actions_url

      expect_query_result(:policy_actions, 4, 4)
      expect_result_resources_to_include_hrefs(
        "resources",
        MiqAction.select(:id).collect { |ma| api_policy_action_url(nil, ma) }
      )
    end

    it "query policy actions in expanded form" do
      api_basic_authorize collection_action_identifier(:policy_actions, :read, :get)
      create_actions(4)

      get api_policy_actions_url, :params => { :expand => "resources" }

      expect_query_result(:policy_actions, 4, 4)
      expect_result_resources_to_include_data("resources", "guid" => miq_action_guid_list)
    end

    it "returns the correct href_slug" do
      policy = FactoryBot.create(:miq_action, :name => "action_policy_1")
      api_basic_authorize collection_action_identifier(:policy_actions, :read, :get)

      get(api_policy_actions_url, :params => { :expand => "resources", :attributes => 'href_slug' })

      expected = {
        'resources' => [
          a_hash_including('href_slug' => "policy_actions/#{policy.id}")
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end

  context "Policy Action subcollection" do
    let(:policy)             { FactoryBot.create(:miq_policy, :name => "Policy 1") }

    def relate_actions_to(policy)
      MiqAction.all.collect(&:id).each do |action_id|
        MiqPolicyContent.create(:miq_policy_id => policy.id, :miq_action_id => action_id)
      end
    end

    it "query policy actions with no actions defined" do
      api_basic_authorize collection_action_identifier(:policy_actions, :read, :get)

      get api_policy_policy_actions_url(nil, policy)

      expect_empty_query_result(:policy_actions)
    end

    it "query policy actions" do
      api_basic_authorize collection_action_identifier(:policy_actions, :read, :get)
      create_actions(4)
      relate_actions_to(policy)

      get api_policy_policy_actions_url(nil, policy), :params => { :expand => "resources" }

      expect_query_result(:policy_actions, 4, 4)
      expect_result_resources_to_include_data("resources", "guid" => miq_action_guid_list)
    end

    it "query policy with expanded policy actions" do
      api_basic_authorize action_identifier(:policies, :read, :resource_actions, :get)
      create_actions(4)
      relate_actions_to(policy)

      get api_policy_url(nil, policy), :params => { :expand => "policy_actions" }

      expect_single_resource_query("name" => policy.name, "description" => policy.description, "guid" => policy.guid)
      expect_result_resources_to_include_data("policy_actions", "guid" => miq_action_guid_list)
    end
  end
end
