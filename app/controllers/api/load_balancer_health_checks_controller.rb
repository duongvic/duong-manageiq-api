module Api
  class LoadBalancerHealthChecksController < BaseController
    include Subcollections::LoadBalancerHealthChecks
    include Subcollections::LoadBalancerPoolMembers
  end
end
