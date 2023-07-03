module Api
  module Subcollections
    module LoadBalancerPoolMembers
      def load_balancer_pool_members_query_resource(object)
        object.respond_to?(:load_balancer_pool_members) ? object.load_balancer_pool_members : []
      end
    end
  end
end
