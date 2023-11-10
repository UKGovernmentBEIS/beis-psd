module Prism
  class Tasks::EvaluateController < ApplicationController
    include Wicked::Wizard

    before_action :prism_risk_assessment
    before_action :disallow_editing_submitted_prism_risk_assessment
    before_action :harm_scenarios
    before_action :items_in_use
    before_action :evaluation
    before_action :set_wizard_steps
    before_action :setup_wizard
    before_action :validate_step

    def show
      render_wizard
    end

    def update
      case step
      when :consider_the_nature_of_the_risk, :consider_perception_and_tolerability_of_the_risk, :risk_evaluation_outcome
        @evaluation.assign_attributes(send("#{step}_params"))
      end

      @prism_risk_assessment.tasks_status[step.to_s] = "completed"
      @prism_risk_assessment.submit! if step == wizard_steps.last

      if params[:draft] == "true" || params[:final] == "true"
        # "Save as draft" or final save button of the section clicked.
        # Manually save, then finish the wizard.
        if @prism_risk_assessment.save(context: step)
          redirect_to wizard_path(Wicked::FINISH_STEP)
        else
          render_wizard
        end
      elsif @prism_risk_assessment.submitted?
        redirect_to confirmation_risk_assessment_tasks_path(@prism_risk_assessment)
      else
        render_wizard(@prism_risk_assessment, { context: step })
      end
    end

  private

    def prism_risk_assessment
      @prism_risk_assessment ||= Prism::RiskAssessment.includes(:associated_investigations, :associated_products, :product_market_detail, :harm_scenarios, :evaluation).find_by!(id: params[:risk_assessment_id], created_by_user_id: current_user.id)
    end

    def disallow_editing_submitted_prism_risk_assessment
      redirect_to view_submitted_assessment_risk_assessment_tasks_path(@prism_risk_assessment) if @prism_risk_assessment.submitted?
    end

    def harm_scenarios
      @harm_scenarios ||= @prism_risk_assessment.harm_scenarios
    end

    def items_in_use
      @items_in_use ||= @prism_risk_assessment.product_market_detail.total_products_sold unless @prism_risk_assessment.serious_risk?
    end

    def evaluation
      @evaluation ||= @prism_risk_assessment.evaluation
    end

    def set_wizard_steps
      self.steps = @prism_risk_assessment.serious_risk? ? SERIOUS_RISK_EVALUATE_STEPS : NORMAL_RISK_EVALUATE_STEPS
    end

    def validate_step
      # Don't allow access to a step if the step before has not yet been completed.
      # Checks if the step is the first step or the autogenerated "finish" step.
      redirect_to risk_assessment_tasks_path(@prism_risk_assessment) unless (step == previous_step && @prism_risk_assessment.outcome_completed?) || step == :wizard_finish || @prism_risk_assessment.tasks_status[previous_step.to_s] == "completed"
    end

    def finish_wizard_path
      risk_assessment_tasks_path(@prism_risk_assessment)
    end

    def consider_the_nature_of_the_risk_params
      allowed_params = params.require(:evaluation).permit(:number_of_products_expected_to_change, :uncertainty_level_implications_for_risk_management, :comparable_risk_level, :multiple_casualties, :significant_risk_differential, :people_at_increased_risk, :relevant_action_by_others, :factors_to_take_into_account, :draft, other_types_of_harm: [])
      # The form builder inserts an empty hidden field that needs to be removed before validation and saving
      allowed_params[:other_types_of_harm].reject!(&:blank?)
      allowed_params
    end

    def consider_perception_and_tolerability_of_the_risk_params
      params.require(:evaluation).permit(:other_hazards, :low_likelihood_high_severity, :risk_to_non_users, :aimed_at_vulnerable_users, :designed_to_provide_protective_function, :user_control_over_risk, :other_risk_perception_matters, :draft)
    end

    def risk_evaluation_outcome_params
      params.require(:evaluation).permit(:risk_tolerability, :draft)
    end
  end
end
