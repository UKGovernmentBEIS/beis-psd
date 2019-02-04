class Investigations::MsaInvestigationsController < ApplicationController
  include Wicked::Wizard
  include CountriesHelper
  include ProductsHelper
  include BusinessesHelper
  include CorrectiveActionsHelper
  include TestsHelper
  include FileConcern
  set_attachment_names :file
  set_file_params_key  :file

  steps :product, :why_reporting, :which_businesses, :business, :has_corrective_action, :corrective_action,
        :other_information, :test_results, :risk_assessments, :product_images, :evidence_images, :other_files,
        :reference_number
  before_action :set_product, only: %i[show create update]
  before_action :set_investigation, only: %i[show create update]
  before_action :set_countries, only: %i[show create update]
  before_action :store_product, only: %i[update]
  before_action :store_investigation, only: %i[update]
  before_action :set_why_reporting, ony: %i[show update], if: -> { step == :why_reporting }
  before_action :store_why_reporting, ony: %i[update], if: -> { step == :why_reporting }
  before_action :set_selected_businesses, ony: %i[show update], if: -> { step == :which_businesses }
  before_action :store_selected_businesses, ony: %i[update], if: -> { step == :which_businesses }

  #GET /xxx/step
  def show
    case step
    when :business
      next_business = session[:businesses].find { |entry| entry["business"].nil? }
      if next_business
        @business_type = next_business["type"]
        set_business
      else
        return redirect_to next_wizard_path
      end
    when :corrective_action
      set_corrective_action
      set_attachment
      unless session[pending(step)]
        return redirect_to next_wizard_path
      end
    when :test_results
      set_test
      unless session[pending(step)]
        return redirect_to next_wizard_path
      end
    when *other_information_types # test_results exists in this array, but has been dealt with above
      @errors = ActiveModel::Errors.new(ActiveStorage::Blob.new)
      @file_blob, * = load_file_attachments
      unless session[pending(step)]
        return redirect_to next_wizard_path
      end
    end
    render_wizard
  end

  # GET /xxx/new
  def new
    clear_session
    redirect_to wizard_path(steps.first)
  end

  def create
    if records_saved?
      redirect_to investigation_path(@investigation)
    else
      render_wizard
    end
  end

  # PATCH/PUT /xxx
  def update
    if records_valid?
      case step
      when :which_businesses
        store_selected_businesses
        store_pending_businesses
      when :business
        store_business
        return redirect_to wizard_path step
      when :has_corrective_action
        store_corrective_action_pending
      when :corrective_action
        store_corrective_action
        store_corrective_action_pending
        return redirect_to wizard_path step
      when :other_information
        store_other_information
      when :test_results
        store_test
        store_is_pending step
        return redirect_to wizard_path step
      when *other_information_types # test_results exists in this array, but has been dealt with above
        store_file
        store_is_pending step
        return redirect_to wizard_path step
      when steps.last
        return create
      end
      redirect_to next_wizard_path
    else
      render_wizard
    end
  end

private

  def store_is_pending(step)
    info = pending(step)
    session[info] = params.permit(info)[info] == "Yes"
  end

  def set_product
    @product = Product.new(product_step_params)
  end

  def set_investigation
    @investigation = Investigation.new(investigation_step_params.except(:unsafe, :non_compliant))
  end

  def set_why_reporting
    @unsafe = investigation_step_params.include?(:unsafe) ? product_unsafe : session[:unsafe]
    @non_compliant = investigation_step_params.include?(:non_compliant) ?
                         product_non_compliant :
                         session[:non_compliant]
  end

  def set_selected_businesses
    if params.has_key?(:businesses)
      @selected_businesses = which_businesses_params
                                 .select { |key, selected| key != :other_type && selected == "1" }
                                 .keys
    else
      @selected_businesses = session[:selected_businesses]
    end
  end

  def set_business
    @business = Business.new business_step_params
    @business.locations.build
    @business.build_contact
  end

  def clear_session
    session.delete :investigation
    session.delete :product
    session.delete :unsafe
    session.delete :non_compliant
    session[:corrective_actions] = []
    session[:test_results] = []
    session[:files] = []
    session[:product_files] = []
    session.delete :file
    session[:selected_businesses] = []
    session[:businesses] = []
  end

  def store_investigation
    session[:investigation] = @investigation.attributes if changed_investigation && @investigation.valid?(step)
  end

  def store_product
    if changed_product && @product.valid?(step)
      session[:product] = @product.attributes
    end
  end

  def investigation_session_params
    session[:investigation] || {}
  end

  def product_session_params
    session[:product] || {}
  end

  def investigation_request_params
    return {} if params[:investigation].blank?

    case step
    when :why_reporting
      params.require(:investigation).permit(
        :unsafe, :hazard, :hazard_type, :hazard_description, :non_compliant, :non_compliant_reason
      )
    when :reference_number
      params.require(:investigation).permit(:reporter_reference)
    end
  end

  def product_request_params
    return {} if params[:product].blank?

    product_params
  end

  def business_request_params
    return {} if params[:business].blank?

    business_params
  end

  def investigation_step_params
    investigation_session_params.merge(investigation_request_params).symbolize_keys
  end

  def product_step_params
    product_session_params.merge(product_request_params).symbolize_keys
  end

  def business_step_params
    business_session_params.merge(business_request_params).symbolize_keys
  end

  def business_session_params
    # TODO use this to retrieve a business for editing eg for browser back button
    {}
  end

  def corrective_action_session_params
    # TODO use this to retrieve a corrective action for editing eg for browser back button
    {}
  end

  def test_session_params
    # TODO use this to retrieve a test for editing eg for browser back button
    { type: Test::Result.name }
  end

  def which_businesses_params
    params.require(:businesses).permit(
      :retailer, :distributor, :importer, :manufacturer, :other, :other_business_type, :none
    )
  end

  def other_information_params
    params.permit(*other_information_types)
  end

  def other_information_types
    [:test_results, :risk_assessments, :product_images, :evidence_images, :other_files]
  end

  def store_selected_businesses
    session[:selected_businesses] = @selected_businesses
  end

  def store_pending_businesses
    if which_businesses_params["none"] == "1"
      session[:businesses] = []
    else
      businesses = which_businesses_params
                       .select {|relationship, selected| relationship != "other" && selected == "1"}
                       .keys
      businesses << which_businesses_params[:other_business_type] if which_businesses_params[:other] == "1"
      session[:businesses] = businesses.map {|type| {type: type, business: nil}}
    end
  end

  def store_why_reporting
    session[:unsafe] = @unsafe
    session[:non_compliant] = @non_compliant
  end

  def store_business
    business_entry = session[:businesses].find { |entry| entry["type"] == params.require(:business)[:business_type] }
    business_entry["business"] = Business.new business_step_params
  end

  def store_corrective_action
    set_corrective_action
    @file_blob, * = load_file_attachments :corrective_action
    update_blob_metadata @file_blob, corrective_action_file_metadata
    @file_blob.save if @file_blob
    session[:corrective_actions] << { corrective_action: @corrective_action, file_blob_id: @file_blob&.id }
    session.delete :file
  end

  def store_test
    set_test
    @file_blob, * = load_file_attachments :test
    update_blob_metadata @file_blob, test_file_metadata
    @file_blob.save if @file_blob
    session[:test_results] << { test: @test, file_blob_id: @file_blob&.id }
    session.delete :file
  end

  def store_file
    @file_blob, * = load_file_attachments
    update_blob_metadata @file_blob, get_attachment_metadata_params(:file)
    @file_blob.save!
    if step == :product_images
      session[:product_files] << @file_blob.id
    else
      session[:files] << @file_blob.id
    end
    session.delete :file
  end

  def pending_corrective_action_params
    params.permit(:has_action)
  end

  def store_corrective_action_pending
    session[:corrective_action_pending] = pending_corrective_action_params[:has_action] == "Yes"
  end

  def store_other_information
    other_information_types.each do |info|
      session[pending(info)] = other_information_params[info] == "1"
    end
  end

  def pending(info)
    (info.to_s + "_pending").to_sym
  end

  def records_valid?
    case step
    when :product
      @product.validate
    when :why_reporting
      @investigation.errors.add(:base, "Please indicate whether the product is unsafe or non-compliant") if !product_unsafe && !product_non_compliant
      @investigation.validate :unsafe if product_unsafe
      @investigation.validate :non_compliant if product_non_compliant
    when :which_businesses
      validate_none_as_only_selection
      @investigation.errors.add(:base, "Please indicate which if any business is known") if no_business_selected
      @investigation.errors.add(:other_business, "type can't be blank") if no_other_business_type
    when :has_corrective_action
      @investigation.errors.add(:base, "Please indicate whether or not correction actions have been agreed or taken") if corrective_action_not_known
    end
    @investigation.errors.empty? && @product.errors.empty?
  end

  def validate_none_as_only_selection
    if @selected_businesses.include?("none") && @selected_businesses.length > 1
      @investigation.errors.add(:none, "has to be the only option if selected")
    end
  end

  def records_saved?
    return false unless records_valid?

    if !@product.save
      return false
    end

    if !@investigation.save
      return false
    end

    @investigation.products << @product

    save_businesses
    save_corrective_actions
    save_test_results
    save_product_files
    save_files
  end

  def save_businesses
    session[:businesses].each do |session_business|
      business = Business.create(session_business["business"])
      @investigation.add_business(business, session_business["type"])
    end
  end

  def save_corrective_actions
    session[:corrective_actions].each do |session_corrective_action|
      action_record = CorrectiveAction.new(session_corrective_action["corrective_action"])
      action_record.product = @product
      file_blob = ActiveStorage::Blob.find_by(id: session_corrective_action["file_blob_id"])
      if file_blob
        attach_blobs_to_list(file_blob, action_record.documents)
        attach_blobs_to_list(file_blob, @investigation.documents)
      end
      @investigation.corrective_actions << action_record
    end
  end

  def save_test_results
    session[:test_results].each do |session_test_result|
      test_record = Test::Result.new(session_test_result["test"])
      file_blob = ActiveStorage::Blob.find_by(id: session_test_result["file_blob_id"])
      if file_blob
        attach_blobs_to_list(file_blob, test_record.documents)
        attach_blobs_to_list(file_blob, @investigation.documents)
      end
      @investigation.tests << test_record
    end
  end

  def save_files
    session[:files].each do |file_blob_id|
      file_blob = ActiveStorage::Blob.find_by(id: file_blob_id)
      attach_blobs_to_list(file_blob, @investigation.documents)
      AuditActivity::Document::Add.from(file_blob, @investigation)
    end
  end

  def save_product_files
    session[:product_files].each do |file_blob_id|
      file_blob = ActiveStorage::Blob.find_by(id: file_blob_id)
      attach_blobs_to_list(file_blob, @product.documents)
    end
  end

  def product_unsafe
    investigation_step_params[:unsafe] == "1"
  end

  def product_non_compliant
    investigation_step_params[:non_compliant] == "1"
  end

  def no_business_selected
    !which_businesses_params.except(:other_business_type).value?("1")
  end

  def no_other_business_type
    which_businesses_params[:other] == "1" && which_businesses_params[:other_business_type].empty?
  end

  def corrective_action_not_known
    pending_corrective_action_params.empty?
  end

  def changed_investigation
    %i[why_reporting reference_number].include? step
  end

  def changed_product
    step == :product
  end
end
