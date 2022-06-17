module Investigations
  class SupportingInformationController < ApplicationController
    def index
      authorize investigation, :view_non_protected_details?

      @grouped_supporting_information = {
        "Accident or incidents" => investigation.unexpected_events.map(&:decorate),
        "Corrective actions" => investigation.corrective_actions.map(&:decorate),
        "Risk assessments" => investigation.risk_assessments.map(&:decorate),
        "Correspondence" => investigation.correspondences.map(&:decorate),
        "Test results" => investigation.test_results.map(&:decorate)
      }
      @breadcrumbs = {
        items: [
          { text: "Cases", href: all_cases_investigations_path },
          { text: @investigation.pretty_description }
        ]
      }
    end

    def new
      authorize investigation, :update?
      supporting_information_type_form
    end

    def add_to_case
      authorize investigation, :update?
      @add_to_case_action = true
      supporting_information_type_form
    end

    def create
      authorize investigation, :update?
      @add_to_case_action = params["add_to_case_action"].present?
      return render(:new) if supporting_information_type_form.invalid?

      case supporting_information_type_form.type
      when "accident_or_incident"
        redirect_to new_investigation_accident_or_incidents_type_path(@investigation)
      when "comment"
        redirect_to new_investigation_activity_comment_path(@investigation)
      when "corrective_action"
        redirect_to new_investigation_corrective_action_path(@investigation)
      when "correspondence"
        redirect_to new_investigation_correspondence_path(@investigation)
      when "image", "generic_information"
        redirect_to new_investigation_document_path(@investigation)
      when "testing_result"
        redirect_to new_investigation_test_result_path(@investigation)
      when "risk_assessment"
        redirect_to new_investigation_risk_assessment_path(@investigation)
      when "product"
        redirect_to new_investigation_product_path(investigation)
      when "business"
        redirect_to new_investigation_business_path(investigation)
      end
    end

  private

    def investigation
      @investigation ||= Investigation
                        .find_by!(pretty_id: params[:investigation_pretty_id])
                        .decorate
    end

    def supporting_information_type_form
      options = if @add_to_case_action
                  SupportingInformationTypeForm::MAIN_TYPES.merge({ product: "Product", business: "Business" })
                else
                  SupportingInformationTypeForm::MAIN_TYPES
                end

      @supporting_information_type_form ||= SupportingInformationTypeForm.new(type: params[:type], options:)
    end
  end
end
