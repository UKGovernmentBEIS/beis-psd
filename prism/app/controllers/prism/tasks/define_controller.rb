module Prism
  class Tasks::DefineController < ApplicationController
    include Wicked::Wizard

    before_action :prism_risk_assessment
    before_action :set_wizard_steps
    before_action :setup_wizard
    before_action :validate_step

    def show
      case step
      when :add_details_about_products_in_use_and_safety
        @product_market_detail = @prism_risk_assessment.product_market_detail || @prism_risk_assessment.build_product_market_detail
      end

      render_wizard
    end

    def update
      case step
      when :add_assessment_details, :add_evaluation_details
        @prism_risk_assessment.assign_attributes(add_assessment_details_params)
      when :add_details_about_products_in_use_and_safety
        @product_market_detail = @prism_risk_assessment.product_market_detail || @prism_risk_assessment.build_product_market_detail
        @product_market_detail.assign_attributes(add_details_about_products_in_use_and_safety_params)
      end

      @prism_risk_assessment.tasks_status[step.to_s] = "completed"
      @prism_risk_assessment.complete_define_section if step == wizard_steps.last

      if params[:draft] == "true" || params[:final] == "true"
        # "Save as draft" or final save button of the section clicked.
        # Manually save, then finish the wizard.
        if @prism_risk_assessment.save(context: step)
          redirect_to wizard_path(Wicked::FINISH_STEP)
        else
          render_wizard
        end
      else
        render_wizard(@prism_risk_assessment, { context: step })
      end
    end

  private

    def prism_risk_assessment
      @prism_risk_assessment ||= Prism::RiskAssessment.includes(:associated_investigations, :associated_products).find_by!(id: params[:risk_assessment_id], created_by_user_id: current_user.id)
    end

    def set_wizard_steps
      self.steps = @prism_risk_assessment.serious_risk? ? SERIOUS_RISK_DEFINE_STEPS : NORMAL_RISK_DEFINE_STEPS
    end

    def validate_step
      # Don't allow access to a step if the step before has not yet been completed.
      # Checks if the step is the first step or the autogenerated "finish" step.
      redirect_to risk_assessment_tasks_path(@prism_risk_assessment) unless step == previous_step || step == :wizard_finish || @prism_risk_assessment.tasks_status[previous_step.to_s] == "completed"
    end

    def finish_wizard_path
      risk_assessment_tasks_path(@prism_risk_assessment)
    end

    def add_assessment_details_params
      params.require(:risk_assessment).permit(:assessor_name, :assessment_organisation, :draft)
    end

    def add_details_about_products_in_use_and_safety_params
      allowed_params = params
        .require(:product_market_detail)
        .permit(:selling_organisation, :total_products_sold_estimatable, :total_products_sold, :other_safety_legislation_standard, :final, safety_legislation_standards: [])
      # The form builder inserts an empty hidden field that needs to be removed before validation and saving
      allowed_params[:safety_legislation_standards].reject!(&:blank?)
      allowed_params
    end
  end
end
