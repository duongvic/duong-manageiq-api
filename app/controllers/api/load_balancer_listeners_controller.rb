module Api
  class LoadBalancerListenersController < BaseController
    include Subcollections::LoadBalancerListeners
    include Subcollections::LoadBalancerPools
  end
end
