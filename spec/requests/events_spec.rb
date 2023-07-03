#
# REST API Request Tests - Events
#
# Event primary collection:
#   /api/events
#
# Event subcollection:
#   /api/policies/:id/events
#
describe "Events API" do
  let(:miq_event_guid_list) { MiqEventDefinition.pluck(:guid) }

  def create_events(count)
    count.times { FactoryBot.create(:miq_event_definition) }
  end

  context "Event collection" do
    it "query invalid event" do
      api_basic_authorize action_identifier(:events, :read, :resource_actions, :get)

      get api_event_url(nil, 999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "query events with no events defined" do
      api_basic_authorize collection_action_identifier(:events, :read, :get)

      get api_events_url

      expect_empty_query_result(:events)
    end

    it "query events" do
      api_basic_authorize collection_action_identifier(:events, :read, :get)
      create_events(3)

      get api_events_url

      expect_query_result(:events, 3, 3)
      expect_result_resources_to_include_hrefs(
        "resources",
        MiqEventDefinition.select(:id).collect { |med| api_event_url(nil, med) }
      )
    end

    it "query events in expanded form" do
      api_basic_authorize collection_action_identifier(:events, :read, :get)
      create_events(3)

      get api_events_url, :params => { :expand => "resources" }

      expect_query_result(:events, 3, 3)
      expect_result_resources_to_include_data("resources", "guid" => miq_event_guid_list)
    end
  end

  context "Event subcollection" do
    let(:policy)             { FactoryBot.create(:miq_policy, :name => "Policy 1") }

    def relate_events_to(policy)
      MiqEventDefinition.all.collect(&:id).each do |event_id|
        MiqPolicyContent.create(:miq_policy_id => policy.id, :miq_event_definition_id => event_id)
      end
    end

    it "query events with no events defined" do
      api_basic_authorize

      get api_policy_events_url(nil, policy)

      expect_empty_query_result(:events)
    end

    it "query events" do
      api_basic_authorize
      create_events(3)
      relate_events_to(policy)

      get api_policy_events_url(nil, policy), :params => { :expand => "resources" }

      expect_query_result(:events, 3, 3)
      expect_result_resources_to_include_data("resources", "guid" => miq_event_guid_list)
    end

    it "query policy with expanded events" do
      api_basic_authorize action_identifier(:policies, :read, :resource_actions, :get)
      create_events(3)
      relate_events_to(policy)

      get api_policy_url(nil, policy), :params => { :expand => "events" }

      expect_single_resource_query("name" => policy.name, "description" => policy.description, "guid" => policy.guid)
      expect_result_resources_to_include_data("events", "guid" => miq_event_guid_list)
    end
  end
end
