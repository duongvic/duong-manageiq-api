#
# Rest API Request Tests - Groups specs
#
# - Creating a group                      /api/groups                           POST
# - Creating a group via action           /api/groups                           action "create"
# - Creating multiple groups              /api/groups                           action "create"
# - Edit a group                          /api/groups/:id                       action "edit"
# - Edit multiple groups                  /api/groups                           action "edit"
# - Delete a group                        /api/groups/:id                       DELETE
# - Delete a group by action              /api/groups/:id                       action "delete"
# - Delete multiple groups                /api/groups                           action "delete"
#
describe "Groups API" do
  let(:expected_attributes) { %w(id description group_type tenant_id) }

  let(:sample_group1) { {:description => "sample_group_1"} }
  let(:sample_group2) { {:description => "sample_group_2"} }
  let(:group) { FactoryBot.create(:miq_group) }
  let(:group1) { FactoryBot.create(:miq_group, sample_group1) }
  let(:group2) { FactoryBot.create(:miq_group, sample_group2) }

  let(:role3)    { FactoryBot.create(:miq_user_role) }
  let(:tenant3)  { FactoryBot.create(:tenant, :name => "Tenant3") }

  before do
    @user.miq_groups << group
  end

  describe "groups create" do
    it "rejects creation without appropriate role" do
      api_basic_authorize

      post(api_groups_url, :params => sample_group1)

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects group creation with id specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      post(api_groups_url, :params => { "description" => "sample group", "id" => 100 })

      expect_bad_request(/id or href should not be specified/i)
    end

    it "rejects group creation with invalid role specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      post(api_groups_url, :params => { "description" => "sample group", "role" => {"id" => 999_999} })

      expect(response).to have_http_status(:not_found)
    end

    it "rejects group creation with invalid tenant specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      post(api_groups_url, :params => { "description" => "sample group", "tenant" => {"id" => 999_999} })

      expect(response).to have_http_status(:not_found)
    end

    it "rejects group creation with invalid filters specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      post(api_groups_url, :params => { "description" => "sample group", "filters" => {"bogus" => %w(f1 f2)} })

      expect_bad_request(/Invalid filter/i)
    end

    it "supports single group creation" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      post(api_groups_url, :params => sample_group1)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      group_id = response.parsed_body["results"].first["id"]
      expect(MiqGroup.exists?(group_id)).to be_truthy
    end

    it "supports single group creation via action" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      post(api_groups_url, :params => gen_request(:create, sample_group1))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      group_id = response.parsed_body["results"].first["id"]
      expect(MiqGroup.exists?(group_id)).to be_truthy
    end

    it "supports single group creation via action with role and tenant specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      post(api_groups_url, :params => gen_request(:create,
                                                  "description" => "sample_group3",
                                                  "role"        => {"name" => role3.name},
                                                  "tenant"      => {"href" => api_tenant_url(nil, tenant3)}))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      result = response.parsed_body["results"].first
      created_group = MiqGroup.find_by(:id => result["id"])

      expect(created_group).to be_present
      expect(created_group.entitlement.miq_user_role).to eq(role3)

      expect_result_to_match_hash(result,
                                  "description" => "sample_group3",
                                  "tenant_id"   => tenant3.id.to_s)
    end

    it "supports single group creation with filters specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      sample_group = {"description" => "sample_group3",
                      "filters"     => {
                        "managed"   => [["/managed/area/1", "/managed/area/2"]],
                        "belongsto" => ["/managed/infra/1", "/managed/infra/2"],
                      }
      }

      post(api_groups_url, :params => gen_request(:create, sample_group))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      group_id = response.parsed_body["results"][0]["id"]
      expected_group = MiqGroup.find_by(:id => group_id)
      expect(expected_group).to be_present
      expect(expected_group.description).to eq(sample_group["description"])
      expect(expected_group.entitlement).to be_present
      expect(expected_group.entitlement.filters).to eq(sample_group["filters"])
    end

    it "supports single group creation with belongsto filter and a filter expression specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      sample_group = {
        "description"       => "sample_group3",
        "filters"           => {
          "belongsto" => ["/managed/infra/1", "/managed/infra/2"]
        },
        "filter_expression" => {
          "exp" => {
            "and" => [
              {
                "CONTAINS" => {
                  "tag"   => "managed-location",
                  "value" => "ny"
                }
              },
              {
                "CONTAINS" => {
                  "tag"   => "managed-environment",
                  "value" => "prod"
                }
              }
            ]
          }
        }
      }
      post(api_groups_url, :params => gen_request(:create, sample_group))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      group_id = response.parsed_body["results"][0]["id"]
      expected_group = MiqGroup.find_by(:id => group_id)
      expect(expected_group).to be_present
      expect(expected_group.description).to eq(sample_group["description"])
      expect(expected_group.entitlement).to be_present
      expect(expected_group.entitlement.filters).to eq(sample_group["filters"])
      expect(expected_group.entitlement.filter_expression).to eq(sample_group["filter_expression"])
    end

    it "fails to create group with invalid filter specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      sample_group = {
        "description"       => "sample_group3",
        "filters"           => {
          "managed"   => [["/managed/area/1", "/managed/area/2"]],
          "belongsto" => ["/managed/infra/1", "/managed/infra/2"]
        },
        "filter_expression" => {
          "exp" => {
            "CONTAINS" => {
              "tag"   => "managed-environment",
              "value" => "quar"
            }
          }
        }
      }
      post(api_groups_url, :params => gen_request(:create, sample_group))

      expect_bad_request(/cannot have both managed filters and a filter expression/)
    end

    it "supports multiple group creation" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      post(api_groups_url, :params => gen_request(:create, [sample_group1, sample_group2]))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      results = response.parsed_body["results"]
      group1_id = results.first["id"]
      group2_id = results.second["id"]
      expect(MiqGroup.exists?(group1_id)).to be_truthy
      expect(MiqGroup.exists?(group2_id)).to be_truthy
    end
  end

  describe "groups edit" do
    it "rejects group edits without appropriate role" do
      api_basic_authorize
      post(api_groups_url, :params => gen_request(:edit,
                                                  "description" => "updated_group",
                                                  "href"        => api_group_url(nil, group1)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects group edits for invalid resources" do
      api_basic_authorize collection_action_identifier(:groups, :edit)

      post(api_group_url(nil, 999_999), :params => gen_request(:edit, "description" => "updated_group"))

      expect(response).to have_http_status(:not_found)
    end

    it "supports single group edit" do
      @user.miq_groups << group1
      api_basic_authorize collection_action_identifier(:groups, :edit)

      post(api_group_url(nil, group1), :params => gen_request(:edit, "description" => "updated_group"))

      expect_single_resource_query("id"          => group1.id.to_s,
                                   "description" => "updated_group")
      expect(group1.reload.description).to eq("updated_group")
    end

    it "supports multiple group edits" do
      api_basic_authorize collection_action_identifier(:groups, :edit)
      @user.miq_groups << group1
      @user.miq_groups << group2
      post(api_groups_url, :params => gen_request(:edit,
                                                  [{"href" => api_group_url(nil, group1), "description" => "updated_group1"},
                                                   {"href" => api_group_url(nil, group2), "description" => "updated_group2"}]))

      expect_results_to_match_hash("results",
                                   [{"id" => group1.id.to_s, "description" => "updated_group1"},
                                    {"id" => group2.id.to_s, "description" => "updated_group2"}])

      expect(group1.reload.name).to eq("updated_group1")
      expect(group2.reload.name).to eq("updated_group2")
    end
  end

  describe "groups delete" do
    it "rejects group deletion, by post action, without appropriate role" do
      api_basic_authorize

      post(api_groups_url, :params => gen_request(:delete, "description" => "group_description", "href" => api_group_url(nil, 100)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects group deletion without appropriate role" do
      api_basic_authorize

      delete(api_group_url(nil, 100))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects group deletes for invalid groups" do
      api_basic_authorize collection_action_identifier(:groups, :delete)

      delete(api_group_url(nil, 999_999))

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a request to remove a default tenant group' do
      api_basic_authorize collection_action_identifier(:groups, :delete)

      delete(api_group_url(nil, tenant3.default_miq_group_id))

      expect(response).to have_http_status(:forbidden)
    end

    it "supports single group delete" do
      api_basic_authorize collection_action_identifier(:groups, :delete)
      @user.miq_groups << group1

      g1_id = group1.id
      delete(api_group_url(nil, g1_id))

      expect(response).to have_http_status(:no_content)
      expect(MiqGroup.exists?(g1_id)).to be_falsey
    end

    it "supports single group delete action" do
      api_basic_authorize collection_action_identifier(:groups, :delete)
      @user.miq_groups << group1

      g1_id = group1.id
      g1_url = api_group_url(nil, g1_id)

      post(g1_url, :params => gen_request(:delete))

      expect_single_action_result(:success => true, :message => "deleting", :href => api_group_url(nil, group1))
      expect(MiqGroup.exists?(g1_id)).to be_falsey
    end

    it "supports multiple group deletes" do
      api_basic_authorize collection_action_identifier(:groups, :delete)
      @user.miq_groups << group1
      @user.miq_groups << group2

      g1_id, g2_id = group1.id, group2.id
      g1_url, g2_url = api_group_url(nil, g1_id), api_group_url(nil, g2_id)

      post(api_groups_url, :params => gen_request(:delete, [{"href" => g1_url}, {"href" => g2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", [api_group_url(nil, group1), api_group_url(nil, group2)])
      expect(MiqGroup.exists?(g1_id)).to be_falsey
      expect(MiqGroup.exists?(g2_id)).to be_falsey
    end
  end

  describe "tags subcollection" do
    it "can list a group's tags" do
      FactoryBot.create(:classification_department_with_tags)
      Classification.classify(group, "department", "finance")
      api_basic_authorize

      get(api_group_tags_url(nil, group))

      expect(response.parsed_body).to include("subcount" => 1)
      expect(response).to have_http_status(:ok)
    end

    it "can assign a tag to a group" do
      FactoryBot.create(:classification_department_with_tags)
      api_basic_authorize(subcollection_action_identifier(:groups, :tags, :assign))

      post(api_group_tags_url(nil, group), :params => { :action => "assign", :category => "department", :name => "finance" })

      expected = {
        "results" => [
          a_hash_including(
            "success"      => true,
            "message"      => a_string_matching(/assigning tag/i),
            "tag_category" => "department",
            "tag_name"     => "finance"
          )
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "can unassign a tag from a group" do
      FactoryBot.create(:classification_department_with_tags)
      Classification.classify(group, "department", "finance")
      api_basic_authorize(subcollection_action_identifier(:groups, :tags, :unassign))

      post(api_group_tags_url(nil, group), :params => { :action => "unassign", :category => "department", :name => "finance" })

      expected = {
        "results" => [
          a_hash_including(
            "success"      => true,
            "message"      => a_string_matching(/unassigning tag/i),
            "tag_category" => "department",
            "tag_name"     => "finance"
          )
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /groups/:id/custom_button_events' do
    let(:super_admin) { FactoryBot.create(:user, :role => 'super_administrator', :userid => 'alice', :password => 'alicepassword') }
    let!(:custom_button_event) { FactoryBot.create(:custom_button_event, :target => group) }

    it 'returns with the custom button events for the given user' do
      api_basic_authorize(:user => super_admin.userid, :password => super_admin.password)

      get(api_group_custom_button_events_url(nil, group))

      expected = {
        "name"      => "custom_button_events",
        "count"     => 1,
        "resources" => contain_exactly(
          a_hash_including(
            'href' => a_string_matching("custom_button_events/#{custom_button_event.id}")
          )
        )
      }

      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end
