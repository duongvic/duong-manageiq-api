RSpec.describe "Normalization of objects API" do
  it "represents datetimes in ISO8601 format" do
    api_basic_authorize action_identifier(:hosts, :read, :resource_actions, :get)
    host = FactoryBot.create(:host)

    get(api_host_url(nil, host))

    expect(response.parsed_body).to include("created_on" => host.created_on.iso8601)
  end
end
