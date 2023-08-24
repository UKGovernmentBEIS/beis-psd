require "aasm"
require "store_attribute"

module Prism
  class RiskAssessment < ApplicationRecord
    include AASM

    has_one :product, autosave: true, dependent: :destroy
    has_one :product_market_detail, autosave: true, dependent: :destroy
    has_one :product_hazard, autosave: true, dependent: :destroy
    has_many :harm_scenarios, autosave: true, dependent: :destroy

    enum risk_type: {
      "normal_risk" => "normal_risk",
      "serious_risk" => "serious_risk",
    }

    enum level_of_uncertainty: {
      "low" => "low",
      "medium" => "medium",
      "high" => "high",
    }

    store_attribute :routing_questions, :less_than_serious_risk, :boolean

    validates :risk_type, inclusion: %w[normal_risk serious_risk], on: :serious_risk
    validates :less_than_serious_risk, inclusion: [true, false], on: :serious_risk_rebuttable
    validates :serious_risk_rebuttable_factors, presence: true, if: -> { less_than_serious_risk }, on: :serious_risk_rebuttable
    validates :assessor_name, :assessment_organisation, presence: true, on: %i[add_assessment_details add_evaluation_details]
    validate :check_all_harm_scenarios, on: :confirm_overall_product_risk
    validates :level_of_uncertainty, inclusion: %w[low medium high], on: :add_level_of_uncertainty_and_sensitivity_analysis
    validates :sensitivity_analysis, inclusion: [true, false], on: :add_level_of_uncertainty_and_sensitivity_analysis

    before_save :clear_serious_risk_rebuttable_factors

    aasm column: :state, whiny_transitions: false do
      state :draft, initial: true
      state :define_completed
      state :identify_completed
      state :create_completed
      state :evaluate_completed
      state :submitted

      event :complete_define_section do
        transitions from: :draft, to: :define_completed
      end

      event :complete_identify_section do
        transitions from: :define_completed, to: :identify_completed
      end

      event :complete_create_section do
        transitions from: :identify_completed, to: :create_completed do
          guard do
            harm_scenarios.collect(&:valid_for_completion?).exclude?(false)
          end
        end
      end

      # Runs when a new harm scenario is added
      event :uncomplete_create_section do
        transitions from: :create_completed, to: :identify_completed do
          after do
            NORMAL_RISK_EVALUATE_STEPS.map(&:to_s).each do |evaluate_step|
              self.tasks_status[evaluate_step] = "not_started" # rubocop:disable Style/RedundantSelf
            end
          end
        end
      end

      event :complete_evaluate_section do
        transitions from: :create_completed, to: :evaluate_completed
      end

      event :submit do
        transitions from: :evaluate_completed, to: :submitted
      end
    end

  private

    def check_all_harm_scenarios
      harm_scenario_statuses = harm_scenarios.collect(&:valid_for_completion?)
      errors.add(:harm_scenarios, :invalid, invalid: harm_scenario_statuses.tally[false], count: harm_scenario_statuses.length) if harm_scenario_statuses.include?(false)
    end

    def clear_serious_risk_rebuttable_factors
      self.serious_risk_rebuttable_factors = nil unless less_than_serious_risk
    end
  end
end
