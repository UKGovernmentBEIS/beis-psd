module Notifications
  class EditController < ApplicationController
    include Wicked::Wizard
    include BreadcrumbHelper

    before_action :disallow_non_role_users
    before_action :set_notification, except: %i[index]
    before_action :set_steps
    before_action :setup_wizard
    before_action :validate_step, except: %i[index remove_business]
    breadcrumb "cases.label", :your_cases_investigations

    def index
      set_notification
      redirect_to notification_path(@notification)
    end

    def remove_business
      @investigation_business = @notification.investigation_businesses.find(params[:investigation_business_id])
      if request.delete?
        RemoveBusinessFromNotification.call!(notification: @notification, business: @investigation_business.business, user: current_user, silent: true)

        # If the last business has been removed, mark the task as in progress to prevent progression
        if @notification.investigation_businesses.blank?
          @notification.tasks_status["search_for_or_add_a_business"] = "in_progress"
          @notification.save!
        end

        redirect_to notification_edit_path(@notification, "search_for_or_add_a_business")
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to "/404"
    end

    def show
      case step
      when :search_for_or_add_a_business
        @search_query = params[:q].presence

        return redirect_to I18n.t("path_search_query_string", path: request.path, query_string: request.query_string) if !request.query_string.start_with?("search") && @search_query.present?

        sort_by = {
          "name_a_z" => { trading_name: :asc },
          "name_z_a" => { trading_name: :desc }
        }[params[:sort_by]] || { created_at: :desc }

        businesses = if @search_query
                       @search_query.strip!
                       Business.joins(:locations).where("businesses.trading_name ILIKE ?", "%#{@search_query}%")
                               .or(Business.where("businesses.legal_name ILIKE ?", "%#{@search_query}%"))
                               .or(Business.where("CONCAT(locations.postal_code) ILIKE ?", "%#{@search_query}%"))
                               .or(Business.where("businesses.company_number ILIKE ?",  "%#{@search_query}%"))
                               .without_online_marketplaces
                               .distinct
                               .order(sort_by)
                     else
                       Business.without_online_marketplaces.order(sort_by)
                     end

        @records_count = businesses.size
        @pagy, @records = pagy(businesses)
        @existing_business_ids = InvestigationBusiness.where(investigation: @notification).pluck(:business_id)
        @existing_attached_business_ids = @notification.corrective_actions.pluck(:business_id) + @notification.risk_assessments.pluck(:assessed_by_business_id)
        @manage = request.query_string.split("&").first != "search" && @existing_business_ids.present?
      when :add_business_details
        business = if params[:business_id].present?
                     Business.find(params[:business_id])
                   else
                     Business.new
                   end

        @add_business_details_form = AddBusinessDetailsForm.new(trading_name: business.trading_name, legal_name: business.legal_name, company_number: business.company_number, business_id: business.id)

      when :add_business_roles
        @add_business_roles_form = AddBusinessRolesForm.new(business_id: params[:business_id])
      when :add_business_location
        location = if params[:location_id].present?
                     Location.find(params[:location_id])
                   else
                     Location.new
                   end

        @add_location_form = AddLocationForm.new(
          business_id: params[:business_id],
          location_id: location.id,
          address_line_1: location.address_line_1,
          address_line_2: location.address_line_2,
          city: location.city,
          county: location.county,
          country: location.country,
          postal_code: location.postal_code
        )
      when :add_business_contact
        contact = if params[:contact_id].present?
                    Contact.find(params[:contact_id])
                  else
                    Contact.new
                  end

        @add_contact_form = AddContactForm.new(
          business_id: params[:business_id],
          contact_id: params[:contact_id],
          name: contact.name,
          email: contact.email,
          job_title: contact.job_title,
          phone_number: contact.phone_number
        )
      when :confirm_business_details
        @business = Business.find(params[:business_id])
        @locations = @business.locations
        @contacts = @business.contacts
      when :add_supporting_images
        @image_upload = ImageUpload.new(upload_model: @notification)
      end

      render_wizard
    end

    def update
      case step
      when :search_for_or_add_a_business
        return redirect_to "#{wizard_path(:search_for_or_add_a_business)}?search" if params[:add_another_business] == "true"
        return redirect_to wizard_path(:search_for_or_add_a_business) if params[:add_another_business].blank? && params[:final].present?
        return redirect_to wizard_path(:confirm_business_details, business_id: params[:business_id]) if params[:add_another_business].blank?
      when :add_business_details
        @add_business_details_form = AddBusinessDetailsForm.new(add_business_details_params)

        if add_business_details_params[:business_id].blank?
          # Find potential duplicate businesses by looking for the same trading name
          # and preferring results with the same legal name too.
          duplicate_business = Business.where("LOWER(TRIM(legal_name)) = ?", @add_business_details_form.legal_name&.downcase)
                                       .or(Business.where(legal_name: nil))
                                       .or(Business.where(legal_name: ""))
                                       .where("LOWER(TRIM(trading_name)) = ?", @add_business_details_form.trading_name&.downcase)
                                       .without_online_marketplaces
                                       .order(Arel.sql("CASE WHEN legal_name IS NULL OR legal_name = '' THEN 1 ELSE 0 END"))
                                       .order(created_at: :desc)
                                       .limit(1)
                                       .first

          return redirect_to duplicate_business_notification_edit_index_path(@notification, business_id: duplicate_business.id, trading_name: @add_business_details_form.trading_name, legal_name: @add_business_details_form.legal_name) if duplicate_business.present?

        end

        return render_wizard unless @add_business_details_form.valid?

        business = if add_business_details_params[:business_id].present?
                     Business.find(add_business_details_params[:business_id])
                   else
                     Business.new
                   end

        ChangeBusinessNames.call!(
          trading_name: @add_business_details_form.trading_name,
          legal_name: @add_business_details_form.legal_name,
          company_number: @add_business_details_form.company_number,
          user: current_user,
          business:
        )

        return redirect_to wizard_path(:confirm_business_details, business_id: add_business_details_params[:business_id]) if add_business_details_params[:business_id].present?

        additional_params = { business_id: business.id }
      when :add_business_location
        @add_location_form = AddLocationForm.new(add_location_params)

        return render_wizard unless @add_location_form.valid?

        if @add_location_form.location_id.present?
          Location.find(@add_location_form.location_id).update!(add_location_params.except(:location_id))
        else
          Location.create!(
            name: "Registered office address",
            address_line_1: @add_location_form.address_line_1,
            address_line_2: @add_location_form.address_line_2,
            city: @add_location_form.city,
            county: @add_location_form.county,
            country: @add_location_form.country,
            postal_code: @add_location_form.postal_code,
            business_id: @add_location_form.business_id,
            added_by_user_id: current_user.id
          )
        end

        return redirect_to wizard_path(:confirm_business_details, business_id: @add_location_form.business_id) if @add_location_form.location_id.present?

        additional_params = { business_id: @add_location_form.business_id }
      when :add_business_contact
        @add_contact_form = AddContactForm.new(add_contact_params)

        return render_wizard unless @add_contact_form.valid?

        if @add_contact_form.contact_id.present?
          Contact.find(@add_contact_form.contact_id).update!(add_contact_params.except(:contact_id))
        elsif !add_contact_params.except(:business_id).compact_blank.empty?
          Contact.create!(
            name: @add_contact_form.name,
            job_title: @add_contact_form.job_title,
            email: @add_contact_form.email,
            phone_number: @add_contact_form.phone_number,
            business_id: @add_contact_form.business_id,
            added_by_user_id: current_user.id
          )
        end

        return redirect_to wizard_path(:confirm_business_details, business_id: @add_contact_form.business_id) if @add_contact_form.contact_id.present?

        additional_params = { business_id: @add_contact_form.business_id }
      when :confirm_business_details

        additional_params = { business_id: confirm_business_details_params }
      when :add_business_roles
        @add_business_roles_form = AddBusinessRolesForm.new(add_business_roles_params)

        return render_wizard unless @add_business_roles_form.valid?

        business = Business.find(@add_business_roles_form.business_id)
        AddBusinessToNotification.call!(notification: @notification, business:, user: current_user, skip_email: true)

        business = Business.without_online_marketplaces.where(id: @add_business_roles_form.business_id).first

        ChangeBusinessRoles.call!(
          notification: @notification,
          business:,
          user: current_user,
          roles: @add_business_roles_form.roles,
          online_marketplace_id: @add_business_roles_form.online_marketplace_id,
          new_online_marketplace_name: @add_business_roles_form.new_online_marketplace_name,
          authorised_representative_choice: @add_business_roles_form.authorised_representative_choice
        )

        return redirect_to wizard_path(:search_for_or_add_a_business)

      when :add_supporting_images
        if params[:final].blank?
          flash[:success] = nil

          @image_upload = ImageUpload.new(upload_model: @notification)

          if image_upload_params[:file_upload].present?
            file = ActiveStorage::Blob.create_and_upload!(
              io: image_upload_params[:file_upload],
              filename: image_upload_params[:file_upload].original_filename,
              content_type: image_upload_params[:file_upload].content_type
            )
            file.analyze_later
            @image_upload = ImageUpload.new(file_upload: file, upload_model: @notification, created_by: current_user.id)

            if @image_upload.valid?
              @image_upload.save!
              @notification.image_upload_ids.push(@image_upload.id)
              @notification.save!
              flash[:success] = "Supporting image uploaded successfully"
            end
          end

          return render_wizard
        else
          flash[:success] = "You have updated the notification!"
          return redirect_to notification_path(@notification)
        end
      end

      if params[:draft] == "true" || params[:final] == "true"
        # "Save as draft" or final save button of the section clicked.
        # Manually save, then finish the wizard.
        if @notification.save(context: step)
          if @step == :search_for_or_add_a_business && params[:final] == "true"
            @notification.tasks_status["add_business_roles"] = "completed"
            @notification.save!
          end

          redirect_to notification_edit_index_path(@notification)
        else
          render_wizard
        end
      elsif additional_params
        @notification.save!(context: step)
        redirect_to wizard_path(@next_step, additional_params)
      else
        render_wizard(@notification, { context: step })
      end
    end

    def show_duplicate_business
      return redirect_to notification_edit_path(@notification, id: "search_for_or_add_a_business") if params[:trading_name].blank?

      @add_business_details_duplicate_form = AddBusinessDetailsDuplicateForm.new(
        trading_name: params[:trading_name],
        legal_name: params[:legal_name]
      )

      @duplicate_business = Business.without_online_marketplaces.find(params[:business_id])

      render :add_business_details_duplicate
    end

    def update_duplicate_business
      @add_business_details_duplicate_form = AddBusinessDetailsDuplicateForm.new(add_business_details_duplicate_params)

      unless @add_business_details_duplicate_form.valid?
        @duplicate_business = Business.without_online_marketplaces.find(params[:business_id])
        return render :add_business_details_duplicate
      end

      if @add_business_details_duplicate_form.resolution == "existing_record"
        business = Business.without_online_marketplaces.find(params[:business_id])

        AddBusinessToNotification.call!(notification: @notification, business:, user: current_user, skip_email: true)

        redirect_to notification_edit_path(@notification, id: "confirm_business_details", business_id: business.id)
      else
        business = Business.new

        ChangeBusinessNames.call!(
          trading_name: @add_business_details_duplicate_form.trading_name,
          legal_name: @add_business_details_duplicate_form.legal_name,
          notification: @notification,
          user: current_user,
          business:
        )

        AddBusinessToNotification.call!(notification: @notification, business:, user: current_user, skip_email: true)

        redirect_to notification_edit_path(@notification, id: "add_business_location", business_id: business.id)
      end
    end

    def remove_upload
      upload = ImageUpload.find(params[:upload_id])
      if upload.upload_model == @notification
        @notification.image_upload_ids.delete(upload.id)
        @notification.save!
        upload.destroy!
        flash[:success] = "Supporting image removed successfully"
      end
      @image_upload = ImageUpload.new(upload_model: @notification)
      redirect_to notification_edit_path(@notification, :add_supporting_images)
    end

  private

    def disallow_non_role_users
      redirect_to notifications_path unless current_user.can_use_notification_task_list?
    end

    def set_notification
      @notification = Investigation::Notification.includes(:owner_user, :owner_team, :creator_user, :creator_team).where(pretty_id: params[:notification_pretty_id]).first

      if @notification.nil?
        redirect_to "/404"
      else
        @notification
      end
    end

    def set_steps
      self.steps = Investigation::Notification::TASK_LIST_SECTIONS.values.flatten
    end

    def validate_step
      # Ensure objects exist
      unless @notification && current_user
        redirect_to "/404" and return
      end

      user_team = current_user.team

      # Check if the current user or their team is authorized to edit the notification
      authorized_to_edit =
        [@notification.creator_user, @notification.owner_user].include?(current_user) ||
        [@notification.owner_team, @notification.creator_team].include?(user_team) ||
        @notification.non_owner_teams_with_edit_access.include?(user_team)

      # Redirect if not authorized
      redirect_to "/403" unless authorized_to_edit
    end

    def set_notification_product
      @investigation_product = @notification.investigation_products.find(params[:investigation_product_id])
    end

    def finish_wizard_path
      notification_edit_index_path(@notification)
    end

    def add_business_details_params
      params.require(:add_business_details_form).permit(:trading_name, :legal_name, :company_number, :business_id)
    end

    def confirm_business_details_params
      params.require(:business_id)
    end

    def add_business_roles_params
      params.require(:add_business_roles_form).permit(:online_marketplace_id, :new_online_marketplace_name, :authorised_representative_choice, :business_id, :final, roles: [])
    end

    def add_business_details_duplicate_params
      params.require(:add_business_details_duplicate_form).permit(:resolution, :trading_name, :legal_name)
    end

    def add_location_params
      params.require(:add_location_form).permit(:address_line_1, :address_line_2, :city, :county, :postal_code, :country, :business_id, :location_id)
    end

    def add_contact_params
      params.require(:add_contact_form).permit(:name, :job_title, :email, :phone_number, :business_id, :contact_id)
    end

    def image_upload_params
      params.require(:image_upload).permit(:file_upload)
    end
  end
end
