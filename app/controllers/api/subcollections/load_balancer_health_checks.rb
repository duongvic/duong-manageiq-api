module Api
  module Subcollections
    module LoadBalancerHealthChecks
      def load_balancer_health_checks_query_resource(object)
        object.respond_to?(:load_balancer_health_checks) ? object.load_balancer_health_checks : []
      end
    end
  end
end
