module Api
  module Subcollections
    module BackupSchedules
      def backup_schedules_query_resource(object)
        object.respond_to?(:backup_schedule) ? object.backup_schedules : []
      end
    end
  end
end
