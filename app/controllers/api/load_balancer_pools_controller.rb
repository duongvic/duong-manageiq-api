module Api
  class LoadBalancerPoolsController < BaseController
    include Subcollections::LoadBalancerPools
    include Subcollections::LoadBalancerPoolMembers
    include Subcollections::LoadBalancerHealthChecks
  end
end
