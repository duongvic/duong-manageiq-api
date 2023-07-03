module Api
  module Subcollections
    module LoadBalancerListeners
      def load_balancer_listeners_query_resource(object)
        object.respond_to?(:load_balancer_listeners) ? object.load_balancer_listeners : []
      end
    end
  end
end
