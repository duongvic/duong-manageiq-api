module Api
  module Subcollections
    module LoadBalancerPools
      def load_balancer_pools_query_resource(object)
        object.respond_to?(:load_balancer_pools) ? object.load_balancer_pools : []
      end
    end
  end
end
