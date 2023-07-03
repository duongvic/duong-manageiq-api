module Api
  module Subcollections
    module UserProfiles
      def user_profiles_query_resource(object)
        object.respond_to?(:user_profiles) ? object.user_profiles : []
      end
    end
  end
end
