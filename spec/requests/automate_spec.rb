#
# REST API Request Tests - /api/automate
#
describe "Automate API" do
  context "Automate Queries" do
    before(:each) do
      MiqAeDatastore.reset
      FactoryBot.create(:miq_ae_domain, :name => "ManageIQ", :tenant_id => @group.tenant.id)
      custom = FactoryBot.create(:miq_ae_domain, :name => "Custom", :tenant_id => @group.tenant.id)
      ns = FactoryBot.create(:miq_ae_namespace, :name => "Test", :parent => custom)
      system_class = FactoryBot.create(:miq_ae_class, :name => "System", :ae_namespace => ns)
      FactoryBot.create(:miq_ae_field, :name    => "on_entry", :class_id => system_class.id,
                                        :aetype  => "state",    :datatype => "string")
    end

    it "returns domains by default" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      get api_automates_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "name"      => "automate",
        "subcount"  => 2,
        "resources" => a_collection_containing_exactly(
          a_hash_including("name" => "Custom",   "fqname" => "/Custom"),
          a_hash_including("name" => "ManageIQ", "fqname" => "/ManageIQ")
        )
      )
    end

    it 'returns only the requested attributes' do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      get api_automates_url, :params => { :expand => 'resources', :attributes => 'name' }

      expect(response).to have_http_status(:ok)
      response.parsed_body['resources'].each { |res| expect_hash_to_have_only_keys(res, %w(fqname name)) }
    end

    it "default to depth 0 for non-root queries" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      get api_automate_url(nil, "custom")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match(
        [a_hash_including("name" => "Custom", "fqname" => "/Custom")]
      )
    end

    it "supports depth 1" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      get(api_automate_url(nil, "custom"), :params => { :depth => 1 })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "Custom", "fqname" => "/Custom", "domain_fqname" => "/"),
         a_hash_including("name" => "Test", "fqname" => "/Custom/Test", "domain_fqname" => "/Test")]
      )
    end

    it "supports depth -1" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      get(api_automates_url, :params => { :depth => -1 })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "ManageIQ", "fqname" => "/ManageIQ"),
         a_hash_including("name" => "Custom",   "fqname" => "/Custom"),
         a_hash_including("name" => "Test",     "fqname" => "/Custom/Test"),
         a_hash_including("name" => "System",   "fqname" => "/Custom/Test/System")]
      )
    end

    it "supports state_machines search option" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      get(api_automates_url, :params => { :depth => -1, :search_options => "state_machines" })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "Custom", "fqname" => "/Custom"),
         a_hash_including("name" => "Test",   "fqname" => "/Custom/Test"),
         a_hash_including("name" => "System", "fqname" => "/Custom/Test/System")]
      )
    end

    it "always return the fqname" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      get(api_automate_url(nil, "custom/test/system"), :params => {:attributes => "name"})

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array([{"name" => "System", "fqname" => "/Custom/Test/System"}])
    end
  end
end
