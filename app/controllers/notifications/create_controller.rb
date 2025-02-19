module Notifications
  class CreateController < ApplicationController
    include Wicked::Wizard
    include BreadcrumbHelper

    before_action :disallow_non_role_users
    before_action :set_notification, except: %i[index from_product]
    before_action :disallow_changing_submitted_notification, except: %i[index from_product confirmation]
    before_action :set_steps
    before_action :setup_wizard
    before_action :validate_step, except: %i[index from_product add_product remove_product remove_business]
    before_action :set_notification_product, only: %i[show_batch_numbers show_customs_codes show_ucr_numbers update_batch_numbers update_customs_codes update_ucr_numbers delete_ucr_number show_with_notification_product update_with_notification_product remove_with_notification_product]

    breadcrumb "notifications.label", :your_notifications

    def index
      if params[:notification_pretty_id].present?
        set_notification
        disallow_changing_submitted_notification
      else
        # Create a new draft notification then redirect to it
        notification = Investigation::Notification.new(state: "draft")
        CreateNotification.call!(notification:, user: current_user, from_task_list: true, silent: true)
        redirect_to notification_create_index_path(notification)
      end
    end

    def from_product
      # Create a new draft notification with attached product, save progress, then redirect to it
      notification = Investigation::Notification.new(state: "draft")
      product = Product.find(params[:product_id])
      CreateNotification.call!(notification:, product:, user: current_user, from_task_list: true, silent: true)
      notification.tasks_status["search_for_or_add_a_product"] = "in_progress"
      notification.save!(context: :search_for_or_add_a_product)
      redirect_to notification_create_path(notification, "search_for_or_add_a_product")
    end

    def add_product
      # Add a newly-created product to an existing notification, save progress, then redirect to it
      product = Product.find(params[:product_id])
      AddProductToNotification.call!(notification: @notification, product:, user: current_user, skip_email: true)
      @notification.tasks_status["search_for_or_add_a_product"] = "in_progress"
      @notification.save!(context: :search_for_or_add_a_product)
      redirect_to notification_create_path(@notification, "search_for_or_add_a_product")
    end

    def remove_product
      # Don't allows products to be removed once the "add notification details" task has been completed
      return redirect_to notification_create_index_path(@notification) if @notification.tasks_status["add_notification_details"] == "completed"

      @investigation_product = @notification.investigation_products.find(params[:investigation_product_id])

      if request.delete?
        RemoveProductFromNotification.call!(notification: @notification, investigation_product: @investigation_product, user: current_user, silent: true)

        # If the last product has been removed, mark the task as in progress to prevent progression
        if @notification.investigation_products.blank?
          @notification.tasks_status["search_for_or_add_a_product"] = "in_progress"
          @notification.save!
        end

        redirect_to notification_create_path(@notification, "search_for_or_add_a_product")
      end
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

        redirect_to notification_create_path(@notification, "search_for_or_add_a_business")
      end
    end

    def show
      case step
      when :search_for_or_add_a_product
        @page_name = params[:page_name]
        @search_query = params[:q].presence
        if params[:add_a_product_form].present?
          @add_another_product = SearchForOrAddAProductForm.new(add_another_product: params[:add_a_product_form][:add_another_product])
          @add_another_product.valid?
        else
          @add_another_product = SearchForOrAddAProductForm.new
        end
        return redirect_to "#{request.path}?search&#{request.query_string}" if !request.query_string.start_with?("search") && @search_query.present?

        sort_by = {
          "name_a_z" => { name: :asc },
          "name_z_a" => { name: :desc }
        }[params[:sort_by]] || { created_at: :desc }

        products = if @page_name == "your_products"
                     Product.not_retired
                            .includes(investigations: %i[owner_user owner_team])
                            .where(users: { id: current_user.id })
                            .order(sort_by)
                   elsif @page_name == "team_products"
                     team = current_user.team
                     Product.not_retired
                            .includes(investigations: %i[owner_user owner_team])
                            .where(users: { id: team.users.map(&:id) }, teams: { id: team.id })
                            .order(sort_by)
                   elsif @search_query
                     @search_query.strip!
                     Product.not_retired
                            .where("products.name ILIKE ?", "%#{@search_query}%")
                            .or(Product.not_retired.where("products.description ILIKE ?", "%#{@search_query}%"))
                            .or(Product.not_retired.where("products.brand ILIKE ?", "%#{@search_query}%"))
                            .or(Product.not_retired.where("products.product_code ILIKE ?", "%#{@search_query}%"))
                            .or(Product.not_retired.where("CONCAT('psd-', products.id) = LOWER(?)", @search_query))
                            .or(Product.not_retired.where(id: @search_query))
                            .order(sort_by)
                   else
                     Product.not_retired
                     .all.order(sort_by)
                   end

        @records_count = products.size
        @pagy, @records = pagy(products)
        @existing_product_ids = InvestigationProduct.where(investigation: @notification).pluck(:product_id)
        @manage = request.query_string.split("&").first != "search" && @existing_product_ids.present?
      when :add_notification_details
        @change_notification_details_form = ChangeNotificationDetailsForm.new(
          user_title: @notification.user_title,
          description: @notification.description,
          reported_reason: notification_reported_reason_summary(@notification)
        )
      when :add_product_safety_and_compliance_details
        @change_notification_product_safety_compliance_details_form = ChangeNotificationProductSafetyComplianceDetailsForm.new(
          unsafe: %w[unsafe unsafe_and_non_compliant].include?(@notification.reported_reason),
          noncompliant: %w[non_compliant unsafe_and_non_compliant].include?(@notification.reported_reason),
          primary_hazard: @notification.hazard_type,
          primary_hazard_description: @notification.hazard_description,
          noncompliance_description: @notification.non_compliant_reason,
          is_from_overseas_regulator: @notification.is_from_overseas_regulator,
          notifying_country: @notification.notifying_country,
          add_reference_number: @notification.complainant_reference.nil? ? nil : @notification.complainant_reference.present?,
          reference_number: @notification.complainant_reference
        )
      when :add_number_of_affected_units
        @multiple_number_of_affected_units_form = MultipleNumberOfAffectedUnitsForm.from(@notification.investigation_products)
      when :search_for_or_add_a_business
        @search_query = params[:q].presence
        if params[:add_a_business_form].present?
          @add_another_business = SearchForOrAddABusinessForm.new(add_another_business: params[:add_a_business_form][:add_another_business])
          @add_another_business.valid?
        else
          @add_another_business = SearchForOrAddABusinessForm.new
        end

        return redirect_to "#{request.path}?search&#{request.query_string}" if !request.query_string.start_with?("search") && @search_query.present?

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
                               .select("DISTINCT ON (businesses.trading_name, businesses.company_number) businesses.*")
                               .order("businesses.trading_name, businesses.company_number, businesses.id")
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
      when :add_test_reports
        investigation_products = @notification.investigation_products
        @existing_test_results = @notification.test_results.includes(investigation_product: :product)

        if params[:add_a_test_report_form].present?
          @add_another_test_report = AddTestReportsForm.new(add_another_test_report: params[:add_a_test_report_form][:add_another_test_report])
          @add_another_test_report.valid?
        else
          @add_another_test_report = AddTestReportsForm.new
        end

        @manage = request.query_string != "add" && @existing_test_results.present?
        return redirect_to with_product_notification_create_index_path(@notification, step: "add_test_reports", investigation_product_id: investigation_products.first.id) if investigation_products.count == 1 && !@manage

        @choose_investigation_product_form = ChooseInvestigationProductForm.new unless @manage
      when :add_supporting_images
        @image_upload = ImageUpload.new(upload_model: @notification)
      when :add_supporting_documents
        @document_form = DocumentForm.new
      when :add_risk_assessments
        investigation_products = @notification.investigation_products
        @existing_prism_associated_investigations = @notification.prism_associated_investigations.includes(:prism_risk_assessment)
        @existing_risk_assessments = @notification.risk_assessments.includes(investigation_products: :product)
        @manage = request.query_string != "add" && (@existing_prism_associated_investigations.present? || @existing_risk_assessments.present?)
        if params[:add_a_risk_assessment_form].present?
          @add_another_risk_assessment = AddAnotherRiskAssessmentForm.new(add_another_risk_assessment: params[:add_a_risk_assessment_form]&.dig(:add_another_risk_assessment))
          @add_another_risk_assessment.valid?
        else
          @add_another_risk_assessment = AddAnotherRiskAssessmentForm.new
        end

        return redirect_to with_product_notification_create_index_path(@notification, step: "add_risk_assessments", investigation_product_id: investigation_products.first.id) if investigation_products.count == 1 && !@manage

        @choose_investigation_product_form = ChooseInvestigationProductForm.new unless @manage
      when :determine_notification_risk_level
        @risk_level_form = RiskLevelForm.new(risk_level: @notification.risk_level)
        highest_risk_level
      when :record_a_corrective_action
        if params[:add_another_corrective_action_form].present?
          @add_a_corrective_action = RecordACorrectiveActionForm.new(add_another_corrective_action: params[:add_another_corrective_action_form][:add_another_corrective_action])
          @add_a_corrective_action.valid?
        else
          @add_a_corrective_action = RecordACorrectiveActionForm.new
        end

        if @notification.corrective_action_taken.blank? || @notification.corrective_action_taken != "yes"
          @corrective_action_taken_form = CorrectiveActionTakenForm.new(
            corrective_action_taken_yes_no: @notification.corrective_action_taken.present? ? @notification.corrective_action_taken_yes? : nil,
            corrective_action_taken_no_specific: @notification.corrective_action_taken_yes? ? nil : @notification.corrective_action_taken,
            corrective_action_not_taken_reason: @notification.corrective_action_not_taken_reason
          )
          return render :record_a_corrective_action_taken
        elsif params[:investigation_product_ids].present?
          @corrective_action_form = CorrectiveActionForm.new
          @corrective_action_form.date_decided = @corrective_action_form.send(:set_date)
          @investigation_products = @notification.investigation_products.where(id: params[:investigation_product_ids])

          return redirect_to wizard_path(:record_a_corrective_action) if @investigation_products.blank?

          return render :record_a_corrective_action_details
        elsif @notification.corrective_action_taken == "yes"
          investigation_products = @notification.investigation_products
          @existing_corrective_actions = @notification.corrective_actions.includes(investigation_product: :product)
          @manage = request.query_string != "add" && @existing_corrective_actions.present?
          return redirect_to wizard_path(:record_a_corrective_action, investigation_product_ids: [investigation_products.first.id]) if investigation_products.count == 1 && !@manage

          @choose_investigation_products_form = ChooseInvestigationProductsForm.new unless @manage
        else
          return render :record_a_corrective_action_later
        end
      end

      render_wizard
    end

    def update
      case step
      when :search_for_or_add_a_product
        @add_another_product = if params[:search_for_or_add_a_product_form].present?
                                 SearchForOrAddAProductForm.new(search_for_or_add_a_product_params)
                               else
                                 SearchForOrAddAProductForm.new
                               end

        return redirect_to "#{wizard_path(:search_for_or_add_a_product)}?search" if @add_another_product.add_another_product == "true"

        return redirect_to wizard_path(:search_for_or_add_a_product, add_a_product_form: search_for_or_add_a_product_params) if @add_another_product.add_another_product.blank? && params[:final].present?

        if @add_another_product.add_another_product.blank?
          product = Product.find(params[:product_id])
          AddProductToNotification.call!(notification: @notification, product:, user: current_user, skip_email: true)
          return redirect_to wizard_path(:search_for_or_add_a_product)
        end
      when :add_notification_details
        @change_notification_details_form = ChangeNotificationDetailsForm.new(add_notification_details_params.merge(current_user:, notification_id: @notification.id))

        if @change_notification_details_form.valid?
          ChangeNotificationName.call!(
            notification: @notification,
            user_title: add_notification_details_params[:user_title],
            user: current_user,
            silent: true
          )
          ChangeNotificationSummary.call!(
            notification: @notification,
            summary: add_notification_details_params[:description],
            user: current_user,
            silent: true
          )
          ChangeNotificationSafetyAndComplianceData.call!(
            notification: @notification,
            reported_reason: add_notification_details_params[:reported_reason],
            user: current_user,
            silent: true
          )
        else
          return render_wizard
        end
      when :add_product_safety_and_compliance_details
        @change_notification_product_safety_compliance_details_form = ChangeNotificationProductSafetyComplianceDetailsForm.new(add_product_safety_and_compliance_details_params.merge(safe_and_compliant: @notification.reported_reason&.safe_and_compliant?, current_user:))

        if @change_notification_product_safety_compliance_details_form.valid?
          unless @notification.reported_reason&.safe_and_compliant?
            ChangeNotificationSafetyAndComplianceData.call!(
              notification: @notification,
              reported_reason: notification_reported_reason_detailed(unsafe: add_product_safety_and_compliance_details_params[:unsafe], noncompliant: add_product_safety_and_compliance_details_params[:noncompliant]),
              hazard_type: add_product_safety_and_compliance_details_params[:primary_hazard],
              hazard_description: add_product_safety_and_compliance_details_params[:primary_hazard_description],
              non_compliant_reason: add_product_safety_and_compliance_details_params[:noncompliance_description],
              user: current_user,
              silent: true
            )
          end
          ChangeNotificationOverseasRegulator.call!(
            notification: @notification,
            is_from_overseas_regulator: add_product_safety_and_compliance_details_params[:is_from_overseas_regulator] == "true",
            notifying_country: add_product_safety_and_compliance_details_params[:notifying_country],
            user: current_user,
            silent: true
          )
          ChangeNotificationReferenceNumber.call!(
            notification: @notification,
            reference_number: add_product_safety_and_compliance_details_params[:add_reference_number] ? add_product_safety_and_compliance_details_params[:reference_number] : nil,
            user: current_user,
            silent: true
          )
        else
          return render_wizard
        end
      when :add_number_of_affected_units
        @multiple_number_of_affected_units_form = MultipleNumberOfAffectedUnitsForm.new(add_number_of_affected_units_params)

        if @multiple_number_of_affected_units_form.valid?
          @multiple_number_of_affected_units_form.number_of_affected_units_forms.each do |f|
            ChangeNumberOfAffectedUnits.call!(
              investigation_product: @notification.investigation_products.find(f.investigation_product_id),
              number_of_affected_units: f.number_of_affected_units,
              affected_units_status: f.affected_units_status,
              user: current_user,
              silent: true
            )
          end
        else
          return render_wizard
        end
      when :search_for_or_add_a_business
        @add_another_business = if params[:search_for_or_add_a_business_form].present?
                                  SearchForOrAddABusinessForm.new(search_for_or_add_a_business_params)
                                else
                                  SearchForOrAddABusinessForm.new
                                end
        return redirect_to "#{wizard_path(:search_for_or_add_a_business)}?search" if @add_another_business.add_another_business == "true"
        return redirect_to wizard_path(:search_for_or_add_a_business, add_a_business_form: search_for_or_add_a_business_params) if @add_another_business.add_another_business.blank? && params[:final].present?
        return redirect_to wizard_path(:confirm_business_details, business_id: params[:business_id]) if @add_another_business.add_another_business.blank?
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

          return redirect_to duplicate_business_notification_create_index_path(@notification, business_id: duplicate_business.id, trading_name: @add_business_details_form.trading_name, legal_name: @add_business_details_form.legal_name) if duplicate_business.present?

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
      when :add_test_reports
        @add_another_test_report = if params[:add_test_reports_form].present?
                                     AddTestReportsForm.new(add_test_report_params)
                                   else
                                     AddTestReportsForm.new
                                   end

        return redirect_to "#{wizard_path(:add_test_reports)}?add" if @add_another_test_report.add_another_test_report == "true"
        return redirect_to wizard_path(:add_test_reports, add_a_test_report_form: add_test_report_params) if @add_another_test_report.add_another_test_report.blank? && params[:final].present?

        if @add_another_test_report.add_another_test_report.blank?
          @choose_investigation_product_form = ChooseInvestigationProductForm.new(add_test_reports_params)

          if @choose_investigation_product_form.valid?
            return redirect_to with_product_notification_create_index_path(@notification, step: "add_test_reports", investigation_product_id: add_test_reports_params[:investigation_product_id])
          else
            return render_wizard
          end
        end
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
        end
      when :add_supporting_documents
        if params[:final].blank?
          flash[:success] = nil

          @document_form = DocumentForm.new(document_upload_params)
          @document_form.cache_file!(current_user)

          if @document_form.valid?
            @notification.documents.attach(@document_form.document)
            flash[:success] = "Supporting document uploaded successfully"
          end

          return render_wizard
        end
      when :add_risk_assessments

        @add_another_risk_assessment = if params[:add_another_risk_assessment_form].present?
                                         AddAnotherRiskAssessmentForm.new(add_another_risk_assessment_params)
                                       else
                                         AddAnotherRiskAssessmentForm.new
                                       end

        return redirect_to "#{wizard_path(:add_risk_assessments)}?add" if params[:add_another_risk_assessment_form]&.dig(:add_another_risk_assessment) == "true"
        return redirect_to wizard_path(:add_risk_assessments, add_a_risk_assessment_form: add_another_risk_assessment_params) if params[:add_another_risk_assessment_form]&.dig(:add_another_risk_assessment).blank? && params[:final].present?

        if params[:add_another_risk_assessment_form]&.dig(:add_another_risk_assessment).blank?
          @choose_investigation_product_form = ChooseInvestigationProductForm.new(add_risk_assessments_params)

          if @choose_investigation_product_form.valid?
            return redirect_to with_product_notification_create_index_path(@notification, step: "add_risk_assessments", investigation_product_id: add_risk_assessments_params[:investigation_product_id])
          else
            return render_wizard
          end
        end
      when :determine_notification_risk_level
        @risk_level_form = RiskLevelForm.new(risk_level: determine_notification_risk_level_params[:risk_level])

        if @risk_level_form.valid?
          ChangeNotificationRiskLevel.call!(
            notification: @notification,
            risk_level: @risk_level_form.risk_level,
            user: current_user,
            silent: true
          )
        else
          highest_risk_level
          return render_wizard
        end
      when :record_a_corrective_action
        if params[:corrective_action_taken_form].present?
          @corrective_action_taken_form = CorrectiveActionTakenForm.new(corrective_action_taken_params)

          if @corrective_action_taken_form.valid?
            ChangeNotificationCorrectiveActionTaken.call!(
              notification: @notification,
              corrective_action_taken: @corrective_action_taken_form.corrective_action_taken,
              corrective_action_not_taken_reason: @corrective_action_taken_form.corrective_action_not_taken_reason,
              user: current_user,
              silent: true
            )

            if @corrective_action_taken_form.corrective_action_taken == "yes"
              return redirect_to wizard_path(:record_a_corrective_action)
            else
              return render :record_a_corrective_action_later
            end
          else
            return render :record_a_corrective_action_taken
          end
        elsif params[:investigation_product_ids].present?
          @corrective_action_form = CorrectiveActionForm.new(record_a_corrective_action_details_params.merge(duration: "unknown"))
          @corrective_action_form.date_decided = @corrective_action_form.send(:set_date)
          @corrective_action_form.cache_file!(current_user)
          @investigation_products = @notification.investigation_products.where(id: params[:investigation_product_ids])

          if @corrective_action_form.valid?
            @investigation_products.each do |investigation_product|
              AddCorrectiveActionToNotification.call!(
                notification: @notification,
                investigation_product_id: investigation_product.id,
                action: @corrective_action_form.action,
                has_online_recall_information: @corrective_action_form.has_online_recall_information,
                online_recall_information: @corrective_action_form.online_recall_information,
                date_decided: @corrective_action_form.date_decided,
                legislation: @corrective_action_form.legislation,
                business_id: @corrective_action_form.business_id,
                measure_type: @corrective_action_form.measure_type,
                duration: @corrective_action_form.duration,
                geographic_scopes: @corrective_action_form.geographic_scopes,
                details: @corrective_action_form.details,
                document: @corrective_action_form.document,
                user: current_user,
                silent: true
              )
            end

            return redirect_to wizard_path(:record_a_corrective_action)
          else
            return render :record_a_corrective_action_details
          end
        elsif @notification.corrective_action_taken == "yes"
          @add_a_corrective_action = if params[:record_a_corrective_action_form].present?
                                       RecordACorrectiveActionForm.new(add_a_corrective_action_params)
                                     else
                                       RecordACorrectiveActionForm.new
                                     end
          return redirect_to "#{wizard_path(:record_a_corrective_action)}?add" if @add_a_corrective_action.add_another_corrective_action == "true"
          return redirect_to wizard_path(:record_a_corrective_action, add_another_corrective_action_form: add_a_corrective_action_params) if @add_a_corrective_action.add_another_corrective_action.blank? && params[:final].present?

          if @add_a_corrective_action.add_another_corrective_action.blank?
            @choose_investigation_products_form = ChooseInvestigationProductsForm.new(record_a_corrective_action_params)

            if @choose_investigation_products_form.valid?
              return redirect_to wizard_path(:record_a_corrective_action, investigation_product_ids: @choose_investigation_products_form.investigation_product_ids)
            else
              return render_wizard
            end
          end
        end
      when :check_notification_details_and_submit
        return render_wizard unless @notification.ready_to_submit? || params[:draft] == "true"
      end

      @notification.tasks_status[step.to_s] = params[:draft] == "true" ? "in_progress" : "completed"

      if params[:draft] == "true" || params[:final] == "true"
        # "Save as draft" or final save button of the section clicked.
        # Manually save, then finish the wizard.
        if @notification.save(context: step)
          if step == :check_notification_details_and_submit && params[:final] == "true"
            pre_submission_tasks
            @notification.submit!
            return redirect_to confirmation_notification_create_index_path(@notification)
          end

          if @step == :search_for_or_add_a_business && params[:final] == "true"
            @notification.tasks_status["add_business_roles"] = "completed"
            @notification.save!
          end

          redirect_to notification_create_index_path(@notification)
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

    def show_batch_numbers
      render :add_product_identification_details_batch_numbers
    end

    def show_customs_codes
      render :add_product_identification_details_customs_codes
    end

    def show_ucr_numbers
      render :add_product_identification_details_ucr_numbers
    end

    def update_batch_numbers
      ChangeNotificationBatchNumber.call!(notification_product: @investigation_product, batch_number: params[:batch_number], user: current_user, silent: true)
      redirect_to wizard_path(:add_product_identification_details)
    end

    def update_customs_codes
      ChangeCustomsCode.call!(investigation_product: @investigation_product, customs_code: params[:customs_code], user: current_user, silent: true)
      redirect_to wizard_path(:add_product_identification_details)
    end

    def update_ucr_numbers
      ChangeUcrNumbers.call!(investigation_product: @investigation_product, ucr_numbers: ucr_numbers_params, user: current_user, silent: true)
      redirect_to wizard_path(:add_product_identification_details)
    end

    def delete_ucr_number
      ucr_number = @investigation_product.ucr_numbers.find(params[:ucr_number_id])
      ucr_number.destroy!
      redirect_to ucr_numbers_notification_create_index_path
    end

    def show_duplicate_business
      return redirect_to notification_create_path(@notification, id: "search_for_or_add_a_business") if params[:trading_name].blank?

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

        redirect_to notification_create_path(@notification, id: "confirm_business_details", business_id: business.id)
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

        redirect_to notification_create_path(@notification, id: "add_business_location", business_id: business.id)
      end
    end

    def show_with_notification_product
      case params[:step].to_sym
      when :add_test_reports
        if params[:entity_id].present?
          @test_result = @investigation_product.test_results.find(params[:entity_id])

          if @test_result.tso_certificate_issue_date.present? || params[:opss_funded] == "false"
            @test_result_form = TestResultForm.from(@test_result)
            render :add_test_reports_details
          else
            @set_test_result_certificate_on_case_form = SetTestResultCertificateOnCaseForm.new
            render :add_test_reports_funding_details
          end
        else
          @set_test_result_funding_on_case_form = SetTestResultFundingOnCaseForm.new
          render :add_test_reports_opss_funding
        end
      when :add_risk_assessments
        if params[:entity_id] == "new"
          @risk_assessment_form = RiskAssessmentForm.new
          render :add_risk_assessments_legacy
        else
          # Find all submitted PRISM risk assessments that are associated with the chosen product
          # either directly or via a notification that is not the current notification.
          @related_prism_risk_assessments = PrismRiskAssessment
                                              .left_joins(:prism_associated_products, prism_associated_investigations: :prism_associated_investigation_products)
                                              .where(prism_associated_products: { product_id: @investigation_product.product.id })
                                              .or(PrismRiskAssessment.where(prism_associated_investigations: { prism_associated_investigation_products: { product_id: @investigation_product.product.id } }))
                                              .where.not(id:
                                                           PrismRiskAssessment
                                                             .left_joins(prism_associated_investigations: :prism_associated_investigation_products)
                                                             .where(prism_associated_investigations: { investigation_id: @notification.id }).where(prism_associated_investigations: { prism_associated_investigation_products: { product_id: @investigation_product.product.id } })
                                                             .submitted
                                                             .distinct)
                                              .submitted
                                              .order(updated_at: :desc)
          render :add_risk_assessments_prism_or_legacy
        end
      end
    end

    def update_with_notification_product
      case params[:step].to_sym
      when :add_test_reports
        if params[:entity_id].present?
          @test_result = @investigation_product.test_results.find(params[:entity_id])

          if @test_result.tso_certificate_issue_date.present? || params[:opss_funded] == "false"
            @test_result_form = TestResultForm.new(test_details_params)
            @test_result_form.cache_file!(current_user)
            if @test_result_form.valid?
              UpdateTestResult.call!(
                investigation: @notification,
                investigation_product_id: @investigation_product.id,
                test_result: @test_result,
                legislation: @test_result_form.legislation,
                standards_product_was_tested_against: @test_result_form.standards_product_was_tested_against,
                result: @test_result_form.result,
                failure_details: @test_result_form.failure_details,
                details: @test_result_form.details,
                document: @test_result_form.document,
                date: @test_result_form.date,
                changes: @test_result_form.changes,
                user: current_user,
                silent: true
              )
              redirect_to notification_create_path(@notification, id: "add_test_reports")
            else
              render :add_test_reports_details
            end
          else
            @set_test_result_certificate_on_case_form = SetTestResultCertificateOnCaseForm.new(opss_funding_details_params)

            if @set_test_result_certificate_on_case_form.valid?
              UpdateTestResult.call!(
                investigation: @notification,
                investigation_product_id: @investigation_product.id,
                test_result: @test_result,
                tso_certificate_reference_number: @set_test_result_certificate_on_case_form.tso_certificate_reference_number,
                tso_certificate_issue_date: @set_test_result_certificate_on_case_form.tso_certificate_issue_date,
                changes: {},
                user: current_user,
                silent: true
              )
              redirect_to with_product_and_entity_notification_create_index_path(@notification, step: "add_test_reports", investigation_product_id: @investigation_product.id, entity_id: @test_result.id, opss_funded: params[:opss_funded])
            else
              render :add_test_reports_funding_details
            end
          end
        else
          @set_test_result_funding_on_case_form = SetTestResultFundingOnCaseForm.new(opss_funding_params)

          if @set_test_result_funding_on_case_form.valid?
            test_result = @notification.test_results.create!(investigation_product: @investigation_product)
            redirect_to with_product_and_entity_notification_create_index_path(@notification, step: "add_test_reports", investigation_product_id: @investigation_product.id, entity_id: test_result.id, opss_funded: opss_funding_params[:opss_funded])
          else
            render :add_test_reports_opss_funding
          end
        end
      when :add_risk_assessments
        if params[:entity_id] == "new"
          # Create a legacy risk assessment
          @risk_assessment_form = RiskAssessmentForm.new(risk_assessments_params.merge(investigation_product_ids: [@investigation_product.id], current_user:))
          @risk_assessment_form.send(:set_date)
          @risk_assessment_form.cache_file!
          @risk_assessment_form.load_risk_assessment_file

          if @risk_assessment_form.valid?
            AddRiskAssessmentToNotification.call!(
              notification: @notification,
              investigation_product_ids: [@investigation_product.id],
              assessed_on: @risk_assessment_form.assessed_on,
              risk_level: @risk_assessment_form.risk_level,
              assessed_by_team_id: @risk_assessment_form.assessed_by_team_id,
              assessed_by_other: @risk_assessment_form.assessed_by_other,
              details: @risk_assessment_form.details,
              risk_assessment_file: @risk_assessment_form.risk_assessment_file,
              user: current_user,
              silent: true
            )
            redirect_to notification_create_path(@notification, id: "add_risk_assessments")
          else
            render :add_risk_assessments_legacy
          end
        elsif params[:entity_id].present?
          # Attach an existing PRISM risk assessment
          prism_risk_assessment = PrismRiskAssessment.find(params[:entity_id])
          AddPrismRiskAssessmentToNotification.call!(notification: @notification, product: @investigation_product.product, prism_risk_assessment:)
          redirect_to notification_create_path(@notification, id: "add_risk_assessments")
        end
      end
    end

    def remove_with_notification_product
      case params[:step].to_sym
      when :add_test_reports
        @test_result = @investigation_product.test_results.find(params[:entity_id])
        if request.delete?
          @test_result.destroy!
          redirect_to notification_create_path(@notification, id: "add_test_reports")
        else
          render :remove_test_report
        end
      when :add_risk_assessments
        @risk_assessment = @investigation_product.risk_assessments.find(params[:entity_id])
        if request.delete?
          @risk_assessment.risk_assessed_products.destroy_all
          @risk_assessment.destroy!
          redirect_to notification_create_path(@notification, id: "add_risk_assessments")
        else
          render :remove_risk_assessment
        end
      end
    end

    def update_with_entity
      @corrective_action = @notification.corrective_actions.find(params[:entity_id])
      if request.patch? || request.put?
        @corrective_action_form = CorrectiveActionForm.new(record_a_corrective_action_details_params.merge(duration: "unknown"))
        @corrective_action_form.date_decided = @corrective_action_form.send(:set_date)
        @corrective_action_form.cache_file!(current_user)
        if @corrective_action_form.valid?
          UpdateCorrectiveAction.call!(
            corrective_action: @corrective_action,
            investigation_product_id: @corrective_action.investigation_product_id,
            action: @corrective_action_form.action,
            has_online_recall_information: @corrective_action_form.has_online_recall_information,
            online_recall_information: @corrective_action_form.online_recall_information,
            date_decided: @corrective_action_form.date_decided,
            legislation: @corrective_action_form.legislation,
            business_id: @corrective_action_form.business_id,
            measure_type: @corrective_action_form.measure_type,
            duration: @corrective_action_form.duration,
            geographic_scopes: @corrective_action_form.geographic_scopes,
            details: @corrective_action_form.details,
            related_file: @corrective_action_form.related_file,
            document: @corrective_action_form.document,
            changes: @corrective_action_form.changes,
            user: current_user,
            silent: true
          )

          redirect_to notification_create_path(@notification, id: "record_a_corrective_action")
        else
          render :record_a_corrective_action_details
        end
      else
        @corrective_action_form = CorrectiveActionForm.from(@corrective_action)
        render :record_a_corrective_action_details
      end
    end

    def remove_with_entity
      case params[:step].to_sym
      when :add_risk_assessments
        @prism_associated_investigation = @notification.prism_associated_investigations.find(params[:entity_id])
        if request.delete?
          RemovePrismRiskAssessmentFromNotification.call!(notification: @notification, prism_risk_assessment: @prism_associated_investigation.prism_risk_assessment)
          redirect_to notification_create_path(@notification, id: "add_risk_assessments")
        else
          render :remove_prism_risk_assessment
        end
      when :record_a_corrective_action
        @corrective_action = @notification.corrective_actions.find(params[:entity_id])
        if request.delete?
          @corrective_action.destroy!
          redirect_to notification_create_path(@notification, id: "record_a_corrective_action")
        else
          render :remove_corrective_action
        end
      end
    end

    def remove_upload
      case params[:step].to_sym
      when :add_supporting_images
        @upload = @notification.image_uploads.find(params[:upload_id])
        @type = "supporting image"
      when :add_supporting_documents
        @upload = @notification.documents.find(params[:upload_id])
        @type = "supporting document"
      end

      if request.delete?
        @upload.destroy!
        redirect_to notification_create_path(@notification, id: params[:step])
      end
    end

    def confirmation
      redirect_to notification_create_index_path(@notification) unless @notification.submitted?

      @products = @notification.investigation_products.includes(:product).decorate.map(&:product).map(&:name_with_brand).to_sentence
    end

  private

    def disallow_non_role_users
      redirect_to notifications_path unless current_user.can_use_notification_task_list?
    end

    def set_notification
      @notification = Investigation::Notification.includes(:creator_user).where(pretty_id: params[:notification_pretty_id], creator_user: { id: current_user.id }).first!
    end

    def disallow_changing_submitted_notification
      redirect_to notification_path(@notification) unless @notification.draft?
    end

    def set_steps
      self.steps = Investigation::Notification::TASK_LIST_SECTIONS.values.flatten
    end

    def validate_step
      # Don't allow access to a step if the step before has not yet been completed (taking into account optional and hidden steps).
      # Checks if the step is the first step or the autogenerated "finish" step.
      optional_tasks = Investigation::Notification::TASK_LIST_SECTIONS.slice(*Investigation::Notification::TASK_LIST_SECTIONS_OPTIONAL).values.flatten
      previous_task = TaskListService.previous_task(task: step, all_tasks: wizard_steps, optional_tasks:, hidden_tasks: Investigation::Notification::TASK_LIST_TASKS_HIDDEN)
      redirect_to notification_create_index_path(@notification) unless step == previous_step || step == :wizard_finish || @notification.tasks_status[previous_task.to_s] == "completed"
    end

    def set_notification_product
      @investigation_product = @notification.investigation_products.find(params[:investigation_product_id])
    end

    def finish_wizard_path
      notification_create_index_path(@notification)
    end

    def notification_reported_reason_summary(notification)
      if notification.reported_reason.present?
        if notification.reported_reason == "safe_and_compliant"
          "safe_and_compliant"
        else
          "unsafe_or_non_compliant"
        end
      elsif notification.tasks_status["add_notification_details"] == "completed"
        "unsafe_or_non_compliant"
      end
    end

    def notification_reported_reason_detailed(unsafe:, noncompliant:)
      unsafe = ActiveModel::Type::Boolean.new.cast(unsafe)
      noncompliant = ActiveModel::Type::Boolean.new.cast(noncompliant)

      if unsafe && noncompliant
        "unsafe_and_non_compliant"
      elsif unsafe
        "unsafe"
      else
        "non_compliant"
      end
    end

    def search_for_or_add_a_product_params
      params.require(:search_for_or_add_a_product_form).permit(:add_another_product)
    end

    def search_for_or_add_a_business_params
      params.require(:search_for_or_add_a_business_form).permit(:add_another_business)
    end

    def add_test_report_params
      params.require(:add_test_reports_form).permit(:add_another_test_report)
    end

    def add_a_corrective_action_params
      params.require(:record_a_corrective_action_form).permit(:add_another_corrective_action)
    end

    def add_another_risk_assessment_params
      params.require(:add_another_risk_assessment_form).permit(:add_another_risk_assessment)
    end

    def add_notification_details_params
      params.require(:change_notification_details_form).permit(:user_title, :description, :reported_reason, :draft)
    end

    def add_product_safety_and_compliance_details_params
      params.require(:change_notification_product_safety_compliance_details_form).permit(:unsafe, :noncompliant, :primary_hazard, :primary_hazard_description, :noncompliance_description, :is_from_overseas_regulator, :notifying_country, :add_reference_number, :reference_number, :draft)
    end

    def add_number_of_affected_units_params
      params.require(:multiple_number_of_affected_units_form).permit(number_of_affected_units_forms_attributes: {})
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

    def ucr_numbers_params
      params.require(:investigation_product).permit(ucr_numbers_attributes: %i[id number _destroy])
    end

    def add_test_reports_params
      params.require(:choose_investigation_product_form).permit(:investigation_product_id, :final)
    end

    def opss_funding_params
      params.require(:set_test_result_funding_on_case_form).permit(:opss_funded)
    end

    def opss_funding_details_params
      params.require(:set_test_result_certificate_on_case_form).permit(:tso_certificate_reference_number, tso_certificate_issue_date: %i[day month year])
    end

    def test_details_params
      params.require(:test_result_form).permit(:legislation, :standards_product_was_tested_against, :result, :failure_details, :details, :existing_document_file_id, :document, date: %i[day month year])
    end

    def image_upload_params
      params.require(:image_upload).permit(:file_upload, :final)
    end

    def document_upload_params
      params.require(:document_form).permit(:document, :title, :final)
    end

    def add_risk_assessments_params
      params.require(:choose_investigation_product_form).permit(:investigation_product_id, :final)
    end

    def risk_assessments_params
      params.require(:risk_assessment_form).permit(:risk_level, :assessed_by, :assessed_by_team_id, :assessed_by_other, :existing_risk_assessment_file_file_id, :risk_assessment_file, :details, "assessed_on(1i)", "assessed_on(2i)", "assessed_on(3i)")
    end

    def determine_notification_risk_level_params
      params.require(:risk_level_form).permit(:risk_level, :final)
    end

    def corrective_action_taken_params
      params.require(:corrective_action_taken_form).permit(:corrective_action_taken_yes_no, :corrective_action_taken_no_specific, :corrective_action_not_taken_reason)
    end

    def record_a_corrective_action_params
      allowed_params = params.require(:choose_investigation_products_form).permit(investigation_product_ids: [])
      # The form builder inserts an empty hidden field that needs to be removed before validation and saving
      allowed_params[:investigation_product_ids].reject!(&:blank?)
      allowed_params
    end

    def record_a_corrective_action_details_params
      allowed_params = params.require(:corrective_action_form).permit(:action, :has_online_recall_information, :online_recall_information, :business_id, :measure_type, :details, :related_file, :existing_document_file_id, :document, legislation: [], geographic_scopes: []).merge("date_decided(1i)" => params[:corrective_action_form]["date_decided(1i)"]).merge("date_decided(2i)" => params[:corrective_action_form]["date_decided(2i)"]).merge("date_decided(3i)" => params[:corrective_action_form]["date_decided(3i)"])
      # The form builder inserts an empty hidden field that needs to be removed before validation and saving
      allowed_params[:legislation].reject!(&:blank?)
      allowed_params[:geographic_scopes].reject!(&:blank?)
      allowed_params
    end

    def highest_risk_level
      all_risk_levels = @notification.risk_assessments.map(&:risk_level) + @notification.prism_risk_assessments.map(&:overall_product_risk_level)
      @number_of_risk_assessments = all_risk_levels.size
      @highest_risk_level = case all_risk_levels
                            in [*, "serious", *]
                              "serious"
                            in [*, "high", *]
                              "high"
                            in [*, "medium", *]
                              "medium"
                            in [*, "low", *]
                              "low"
                            else
                              "unknown"
                            end
    end

    def pre_submission_tasks
      capture_submitted_at_date
      add_incident_management_team
    end

    def add_incident_management_team
      AddImtToNotification.call!(notification: @notification, user: current_user)
    end

    def capture_submitted_at_date
      @notification.submitted_at = Time.zone.now.utc
      @notification.save!
    end
  end
end
