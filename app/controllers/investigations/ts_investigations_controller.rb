class Investigations::TsInvestigationsController < ApplicationController
  include Wicked::Wizard

  steps :reason_for_creating,
        :reason_for_concern,
        :reference_number,
        :case_name,
        :case_created

  before_action :redirect_to_first_step_if_wizard_not_started, if: -> { step && (step != :reason_for_creating) }

  # GET /xxx/step
  def show
    case step
    when :reason_for_creating
      @investigation = Investigation::Allegation.new
      @reason_for_creating_form = ReasonForCreatingForm.new
    when :reason_for_concern
      @investigation = session[:investigation]
      skip_step if @investigation.reported_reason == 'safe_and_compliant'
      @edit_why_reporting_form = EditWhyReportingForm.new
    when :reference_number
      @reference_number_form = ReferenceNumberForm.new
    when :case_name
      @case_name_form = CaseNameForm.new
    when :case_created
      @investigation = session[:investigation]
      @investigation.build_owner_collaborations_from(current_user)
      CreateCase.call(investigation: session[:investigation], user: current_user)
      session.delete :investigation
    end

    render_wizard
  end

  # GET /xxx/new
  def new
    clear_session
    redirect_to wizard_path(steps.first)
  end

  # PATCH/PUT /xxx
  def update
    # If skipping, we've already modified session appropriately, now we need to re-render current step so usual logic
    # can kick in.
    return redirect_to wizard_path(step) if @skip_step

    # if records_valid?
    case step
    when :reason_for_creating
      @reason_for_creating_form = ReasonForCreatingForm.new(reason_for_creating_params)
      if @reason_for_creating_form.case_is_safe == 'true'
        session[:investigation] = Investigation::Allegation.new(reported_reason: 'safe_and_compliant')
      else
        session[:investigation] = Investigation::Allegation.new
      end
    when :reason_for_concern
      reported_reason = calculate_reported_reason(reason_for_concern_params)
      @edit_why_reporting_form = EditWhyReportingForm.new(reason_for_concern_params)
      session[:investigation] = Investigation::Allegation.new(reported_reason: reported_reason, hazard_description: @edit_why_reporting_form.hazard_description,
                                              hazard_type: @edit_why_reporting_form.hazard_type, non_compliant_reason: @edit_why_reporting_form.non_compliant_reason)
    when :reference_number
      @reference_number_form = ReferenceNumberForm.new(reference_number_params)
      session[:investigation].assign_attributes(complainant_reference: @reference_number_form.complainant_reference) if @reference_number_form.has_complainant_reference
    end
    redirect_to next_wizard_path
  end

private

  def calculate_reported_reason(reason_for_concern_params)
    return :unsafe_and_non_compliant if reason_for_concern_params['reported_reason_unsafe'] && reason_for_concern_params['reported_reason_non_compliant']
    return :unsafe                   if reason_for_concern_params['reported_reason_unsafe']
    return :non_compliant            if reason_for_concern_params['reported_reason_non_compliant']
  end

  def clear_session
    session.delete :investigation
  end

  def redirect_to_first_step_if_wizard_not_started
    redirect_to action: :new unless session[:investigation]
  end

  def reason_for_creating_params
    params.require(:investigation).permit(:case_is_safe)
  end

  def reason_for_concern_params
    params.require(:investigation).permit(:hazard_type, :hazard_description, :reported_reason_non_compliant, :reported_reason_unsafe, :non_compliant_reason)
  end

  def reference_number_params
    params.require(:investigation).permit(:has_complainant_reference, :complainant_reference)
  end

  def assign_safety_and_compliance_attributes(reported_reason:, hazard_description:, hazard_type:, non_compliant_reason:)
    if reported_reason.to_s == "safe_and_compliant"
      session[:investigation] = investigation.assign_attributes(hazard_description: nil, hazard_type: nil, non_compliant_reason: nil, reported_reason:)
    end

    if reported_reason.to_s == "unsafe_and_non_compliant"
      session[:investigation] = investigation.assign_attributes(hazard_description:, hazard_type:, non_compliant_reason:, reported_reason:)
    end

    if reported_reason.to_s == "unsafe"
      session[:investigation] = investigation.assign_attributes(hazard_description:, hazard_type:, non_compliant_reason: nil, reported_reason:)
    end

    if reported_reason.to_s == "non_compliant"
      session[:investigation] = investigation.assign_attributes(hazard_description: nil, hazard_type: nil, non_compliant_reason:, reported_reason:)
    end
  end
end
