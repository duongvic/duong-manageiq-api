module Api
  class LoadBalancersController < BaseController
    include Subcollections::LoadBalancers
    include Subcollections::LoadBalancerListeners
    include Subcollections::LoadBalancerPools
    include Subcollections::LoadBalancerPoolMembers
    include Subcollections::LoadBalancerHealthChecks
  end
end
