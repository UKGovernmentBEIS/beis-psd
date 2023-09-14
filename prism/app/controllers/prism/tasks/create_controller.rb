module Prism
  class Tasks::CreateController < ApplicationController
    include Wicked::Wizard

    before_action :prism_risk_assessment
    before_action :harm_scenario
    before_action :set_wizard_steps
    before_action :setup_wizard
    before_action :validate_step

    def show
      case step
      when :add_steps_to_harm
        @harm_scenario.harm_scenario_steps.build if @harm_scenario.harm_scenario_steps.blank?
      when :estimate_probability_of_harm
        @harm_scenario.harm_scenario_steps.each { |hss| hss.build_harm_scenario_step_evidence if hss.harm_scenario_step_evidence.blank? }
      end

      render_wizard
    end

    def update
      case step
      when :add_steps_to_harm
        @harm_scenario.assign_attributes(add_steps_to_harm_params)
        # We have to save the harm scenario manually here since we need to build the steps
        # if it fails to save.
        unless @harm_scenario.save(context: step)
          @harm_scenario.harm_scenario_steps.build if @harm_scenario.harm_scenario_steps.blank?
          return render_wizard
        end
      when :estimate_probability_of_harm
        @harm_scenario.assign_attributes(estimate_probability_of_harm_params)
        # We have to save the harm scenario manually here since we need to build the step
        # evidences if it fails to save.
        unless @harm_scenario.save(context: step)
          @harm_scenario.harm_scenario_steps.each { |hss| hss.build_harm_scenario_step_evidence if hss.harm_scenario_step_evidence.blank? }
          return render_wizard
        end
      when :choose_hazard_type, :identify_who_might_be_harmed, :determine_severity_of_harm, :check_your_harm_scenario
        @harm_scenario.assign_attributes(send("#{step}_params"))
      end

      @harm_scenario.tasks_status[step.to_s] = "completed"

      if params[:draft] == "true" || params[:final] == "true" || params[:harm_scenario][:back_to] == "summary"
        # "Save as draft" or final save button of the section clicked.
        # Manually save, then finish the wizard.
        if @harm_scenario.save(context: step)
          @prism_risk_assessment.complete_create_section! if step == wizard_steps.last

          if params[:harm_scenario][:back_to] == "summary"
            redirect_to wizard_path(:check_your_harm_scenario)
          else
            redirect_to wizard_path(Wicked::FINISH_STEP)
          end
        else
          render_wizard
        end
      else
        render_wizard(@harm_scenario, { context: step }, { harm_scenario_id: @harm_scenario.id })
      end
    rescue ActiveRecord::NestedAttributes::TooManyRecords
      # The user has specified more than the maximum number of harm scenario steps.
      # We get around the lack of meaningful feedback to the user
      # by setting a virtual attribute to a value which is then
      # validated by the model so we can show a nice error message.
      if @harm_scenario
        @harm_scenario.too_many_harm_scenario_steps = true
        @harm_scenario.save!(context: step)
      end

      render_wizard
    end

  private

    def prism_risk_assessment
      @prism_risk_assessment ||= Prism::RiskAssessment.includes(:associated_investigations, :associated_products, :harm_scenarios).find_by!(id: params[:risk_assessment_id], created_by_user_id: current_user.id)
    end

    def harm_scenario
      @harm_scenario ||= @prism_risk_assessment.harm_scenarios.find_by!(id: params[:harm_scenario_id])
    end

    def set_wizard_steps
      self.steps = NORMAL_RISK_CREATE_STEPS
    end

    def validate_step
      # Don't allow access to a step if the step before has not yet been completed.
      # Checks if the step is the first step or the autogenerated "finish" step.
      redirect_to risk_assessment_tasks_path(@prism_risk_assessment) unless (step == previous_step && @prism_risk_assessment.identify_completed?) || step == :wizard_finish || @harm_scenario.tasks_status[previous_step.to_s] == "completed"
    end

    def finish_wizard_path
      risk_assessment_tasks_path(@prism_risk_assessment)
    end

    def choose_hazard_type_params
      params.require(:harm_scenario).permit(:hazard_type, :other_hazard_type, :description, :back_to, :draft)
    end

    def identify_who_might_be_harmed_params
      allowed_params = params
        .require(:harm_scenario)
        .permit(:product_aimed_at, :product_aimed_at_description, :draft, unintended_risks_for: [])
      # The form builder inserts an empty hidden field that needs to be removed before validation and saving
      allowed_params[:unintended_risks_for].reject!(&:blank?)
      allowed_params
    end

    def add_steps_to_harm_params
      params.require(:harm_scenario).permit(:back_to, :draft, harm_scenario_steps_attributes: %i[id _destroy description])
    end

    def determine_severity_of_harm_params
      params.require(:harm_scenario).permit(:severity, :multiple_casualties, :back_to, :draft)
    end

    def estimate_probability_of_harm_params
      params.require(:harm_scenario).permit(:back_to, :draft, harm_scenario_steps_attributes: [:id, :probability_type, :probability_decimal, :probability_frequency, :probability_evidence, :probability_evidence_description_limited, :probability_evidence_description_strong, { harm_scenario_step_evidence_attributes: %i[id evidence_file] }])
    end

    def check_your_harm_scenario_params
      params.require(:harm_scenario).permit(:confirmed)
    end
  end
end
