module Api
  class UsersController < BaseController
    INVALID_USER_ATTRS = %w(id href current_group_id settings current_group).freeze # Cannot update other people's settings
    INVALID_SELF_USER_ATTRS = %w(id href current_group_id current_group).freeze
    EDITABLE_ATTRS = %w(password email settings).freeze

    include Subcollections::CustomButtonEvents
    include Subcollections::Tags
    include Subcollections::UserProfiles

    skip_before_action :validate_api_action, :only => :update

    def update
      aname = @req.action
      if aname == "edit" && !api_user_role_allows?(aname) && update_target_is_api_user?
        if (Array(@req.resource.try(:keys)) - EDITABLE_ATTRS).present?
          raise BadRequestError,
                "Cannot update attributes other than #{EDITABLE_ATTRS.join(', ')} for the authenticated user"
        end
        render_resource(:users, update_collection(:users, @req.collection_id))
      else
        validate_api_action
        super
      end
    end

    def create_resource(_type, _id, data)
      validate_user_create_data(data)
      tenant_parent = Tenant.find(Rails.application.config.default_miq_tenant)
      tenant = Tenant.create(:name => data["userid"], :description => "#{data["userid"]}",
                             :divisible => false, :parent => tenant_parent)

      if tenant.invalid?
        raise BadRequestError, "Failed to add a new user - #{tenant.errors.full_messages.join(', ')}"
      end

      group = MiqGroup.create(:description => "#{data["userid"]}",
                              :miq_user_role => MiqUserRole.find(Rails.application.config.default_miq_role),
                              :tenant => tenant)

      if group.invalid?
        raise BadRequestError, "Failed to add a new user - #{group.errors.full_messages.join(', ')}"
      end

      tenant.update_attribute(:default_miq_group, group)
      data["group"] = {
        "id" => "#{group.id}"
      }

      parse_set_group(data)
      raise BadRequestError, "Must specify a valid group for creating a user" unless data["miq_groups"]
      parse_set_settings(data)
      profile_attr = data.delete("profile")
      user = collection_class(:users).create(data)
      profile = UserProfile.create(profile_attr)
      profile.update_attribute(:evm_owner, user)
      user.update_attribute(:status, true)

      if user.invalid?
        raise BadRequestError, "Failed to add a new user - #{user.errors.full_messages.join(', ')}"
      end
      resp = {
        :user => {
          :id           => user.id,
          :name         => user.name,
          :userid       => user.userid,
          :email        => user.email,
          :phone_number => user.phone_number
        },
        :user_profile => {
          :id                  => profile.id,
          :user_type           => profile.user_type,
          :account_type        => profile.account_type,
          :company             => profile.company,
          :address             => profile.address,
          :tax_number          => profile.tax_number,
          :contract_codes      => profile.contract_codes,
          :date_of_birth       => profile.date_of_birth,
          :id_number           => profile.id_number,
          :id_issue_date       => profile.id_issue_date,
          :id_issue_location   => profile.id_issue_location,
          :rep_name            => profile.rep_name,
          :rep_phone           => profile.rep_phone,
          :rep_email           => profile.rep_email,
          :ref_name            => profile.ref_name,
          :ref_phone           => profile.ref_phone,
          :ref_email           => profile.ref_email
        }
      }
      resp
    rescue => e
      unless tenant.nil? || tenant.id == 1
        MiqProductFeature.where(:tenant_id => tenant.id).destroy_all
        tenant.delete
      end
      group.delete unless group.nil?
      profile.delete unless profile.nil?
      user.delete unless user.nil?
      raise BadRequestError, "Failed to add a new user", e.backtrace
    end

    def edit_resource(type, id, data)
      id == User.current_user.id ? validate_self_user_data(data) : validate_user_data(data)
      profile_attr = data.delete("profile")
      parse_set_group(data)
      parse_set_settings(data, resource_search(id, type, collection_class(type)))
      klass = collection_class(type)
      user = resource_search(id, type, klass)
      user.update!(data.except(*ID_ATTRS))
      profile = UserProfile.find_by(:evm_owner_id => id)
      if profile.nil?
        profile_attr["evm_owner_id"] = id
        profile = UserProfile.create(profile_attr)
      else
        profile.update!(profile_attr)
      end
      resp = {
        :user => {
          :id           => user.id,
          :name         => user.name,
          :userid       => user.userid,
          :email        => user.email,
          :phone_number => user.phone_number
        },
        :user_profile => {
          :id                  => profile.id,
          :user_type           => profile.user_type,
          :account_type        => profile.account_type,
          :company             => profile.company,
          :address             => profile.address,
          :tax_number          => profile.tax_number,
          :contract_codes      => profile.contract_codes,
          :date_of_birth       => profile.date_of_birth,
          :id_number           => profile.id_number,
          :id_issue_date       => profile.id_issue_date,
          :id_issue_location   => profile.id_issue_location,
          :rep_name            => profile.rep_name,
          :rep_phone           => profile.rep_phone,
          :rep_email           => profile.rep_email,
          :ref_name            => profile.ref_name,
          :ref_phone           => profile.ref_phone,
          :ref_email           => profile.ref_email
        }
      }
      resp
    end

    def delete_resource(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for deleting a user" unless id
      raise BadRequestError, "Cannot delete user of current request" if id.to_i == User.current_user.id
      super
    end

    def set_current_group_resource(_type, id, data)
      User.current_user.tap do |user|
        raise "Can only edit authenticated user's current group" unless user.id == id
        group_id = parse_group(data["current_group"])
        raise "Must specify a current_group" unless group_id
        new_group = user.miq_groups.where(:id => group_id).first
        raise "User must belong to group" unless new_group
        # Cannot use update_attributes! due to the allowed ability to switch between groups that may have different RBAC visibility on a user's miq_groups
        user.update_attribute(:current_group, new_group)
      end
    rescue => err
      raise BadRequestError, "Cannot set current_group - #{err}"
    end

    def revoke_sessions_collection(type, data)
      revoke_sessions_resource(type, current_user.id, data)
    end

    def revoke_sessions_resource(type, id, _data)
      api_action(type, id) do |klass|
        user = target_user(id, type, klass)
        api_log_info("Revoking all sessions of user #{user.userid}")

        user.revoke_sessions
        action_result(true, "All sessions revoked successfully for user #{user.userid}.")
      rescue => err
        action_result(false, err.to_s)
      end
    end

    def create_tfa_resource(_type, id, _data)
      unless id == User.current_user.id || User.current_user.super_admin_user?
        raise BadRequestError, "User unauthorized."
        return
      end
      user = User.find(id)
      unless user
        raise BadRequestError, "Not found user: #{id}"
        return
      end
      tfa = TwoFactors.lookup_by_userid(user.id)
      if user.enable_two_factors & tfa
        user.tap do |user|
          user.update_attribute(:enable_two_factors, true)
        end
        tfa.update_attribute(:status, 'pending')
      elsif tfa
        User.find(id).update_attribute(:enable_two_factors, true)
        tfa.update_attribute(:status, 'pending')
      else
        tfa = TwoFactors.new
        pre_setting_tfa(tfa, id)
        unless tfa.valid? && tfa.save!
          raise BadRequestError, "Failed to enable TFA for user: #{id}"
        end

        user.tap do |user|
          user.update_attribute(:enable_two_factors, true)
        end
      end
      response = {
        :otp_token => tfa.format_otp_token
      }
      response
    end

    def verify_otp_resource(type, id, data)
      unless id == User.current_user.id || User.current_user.super_admin_user?
        raise BadRequestError, "User unauthorized."
        return
      end

      tfa = TwoFactors.lookup_by_userid(id)
      raise BadRequestError, "Use not enabled TFA" unless tfa

      unless tfa.verify_otp_token(data['otp'].to_s)
        raise BadRequestError, "Invalid OTP"
      end

      action_result(false, "Invalid OTP")
    end

    def disable_tfa_resource(type, id, data)
      unless id == User.current_user.id || User.current_user.super_admin_user?
        raise BadRequestError, "User unauthorized."
        return
      end

      user = User.find(id)
      unless user
        raise BadRequestError, "Not found user: #{id}"
        return
      end

      if user.enable_two_factors
        tfa = TwoFactors.lookup_by_userid(id)

        unless tfa.verify_otp_token(data['otp'].to_s)
          raise BadRequestError, "Invalid OTP"
        end

        tfa.update_attribute(:status, 'disabled')
        user.tap do |user|
          user.update_attribute(:enable_two_factors, false)
        end
        action_result(true)
      else
        raise BadRequestError, "Use not enabled TFA"
      end
    end

    private

    def pre_setting_tfa(tfa, id)
      tfa.user_id = id
    end

    def target_user(id, type, klass)
      if id == current_user.id
        current_user
      elsif current_user.role_allows?(:identifier => 'revoke_user_sessions')
        resource_search(id, type, klass)
      else
        raise ForbiddenError, "The user is not authorized for this task or item."
      end
    end

    def update_target_is_api_user?
      User.current_user.id == @req.collection_id.to_i
    end

    def parse_set_group(data)
      groups = if data.key?("group")
                 group = parse_fetch_group(data.delete("group"))
                 Array(group) if group
               elsif data.key?("miq_groups")
                 data["miq_groups"].collect do |miq_group|
                   parse_fetch_group(miq_group)
                 end
               end
      data["miq_groups"] = groups if groups
    end

    def parse_set_settings(data, user = nil)
      settings = data.delete("settings")
      if settings.present?
        current_settings = user.nil? ? {} : user.settings
        data["settings"] = Hash(current_settings).deep_merge(settings.deep_symbolize_keys)
      end
    end

    def validate_user_data(data = {})
      bad_attrs = data.keys.select { |k| INVALID_USER_ATTRS.include?(k) }.compact.join(", ")
      raise BadRequestError, "Invalid attribute(s) #{bad_attrs} specified for a user" if bad_attrs.present?
      raise BadRequestError, "Users must be assigned groups" if data.key?("miq_groups") && data["miq_groups"].empty?
    end

    def validate_self_user_data(data = {})
      bad_attrs = data.keys.select { |k| INVALID_SELF_USER_ATTRS.include?(k) }.compact.join(", ")
      raise BadRequestError, "Invalid attribute(s) #{bad_attrs} specified for the current user" if bad_attrs.present?
    end

    def validate_user_create_data(data)
      validate_user_data(data)
      req_attrs = %w(name userid)
      req_attrs << "password" if ::Settings.authentication.mode == "database"
      bad_attrs = []
      req_attrs.each { |attr| bad_attrs << attr if data[attr].blank? }
      # bad_attrs << "group or miq_groups" if !data['group'] && !data['miq_groups']
      raise BadRequestError, "Missing attribute(s) #{bad_attrs.join(', ')} for creating a user" if bad_attrs.present?
    end
  end
end
