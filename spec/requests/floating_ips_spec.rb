RSpec.describe 'FloatingIp API' do
  describe 'GET /api/floating_ips' do
    it 'lists all cloud subnets with an appropriate role' do
      floating_ip = FactoryBot.create(:floating_ip)
      api_basic_authorize collection_action_identifier(:floating_ips, :read, :get)
      get(api_floating_ips_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'floating_ips',
        'resources' => [
          hash_including('href' => api_floating_ip_url(nil, floating_ip))
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids access to cloud subnets without an appropriate role' do
      api_basic_authorize

      get(api_floating_ips_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/floating_ips/:id' do
    it 'will show a cloud subnet with an appropriate role' do
      floating_ip = FactoryBot.create(:floating_ip)
      api_basic_authorize action_identifier(:floating_ips, :read, :resource_actions, :get)

      get(api_floating_ip_url(nil, floating_ip))

      expect(response.parsed_body).to include('href' => api_floating_ip_url(nil, floating_ip))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to a cloud tenant without an appropriate role' do
      floating_ip = FactoryBot.create(:floating_ip)
      api_basic_authorize

      get(api_floating_ip_url(nil, floating_ip))

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/floating_ips' do
    it 'forbids access to floating ips without an appropriate role' do
      api_basic_authorize
      post(api_floating_ips_url, :params => gen_request(:query, ""))
      expect(response).to have_http_status(:forbidden)
    end
  end
end
