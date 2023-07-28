module Prism
  class HarmScenario < ApplicationRecord
    MAX_HARM_SCENARIO_STEPS = 30

    belongs_to :risk_assessment
    has_many :harm_scenario_steps, index_errors: true, dependent: :destroy
    has_many :harm_scenario_step_evidences, through: :harm_scenario_steps, dependent: :destroy

    accepts_nested_attributes_for :harm_scenario_steps, limit: MAX_HARM_SCENARIO_STEPS, allow_destroy: true, reject_if: :all_blank
    accepts_nested_attributes_for :harm_scenario_step_evidences, reject_if: :all_blank

    default_scope { order(created_at: :asc) }

    attribute :too_many_harm_scenario_steps, :boolean, default: false
    attribute :confirmed, :boolean, default: false
    attribute :back_to, :string # This is just here to allow `back_to` to be sent to the controller

    enum hazard_type: {
      "mechanical" => "mechanical",
      "size_and_shape" => "size_and_shape",
      "electrical" => "electrical",
      "fire_and_explosion" => "fire_and_explosion",
      "thermal" => "thermal",
      "ergonomic" => "ergonomic",
      "noise_and_vibration" => "noise_and_vibration",
      "microbiological" => "microbiological",
      "chemical" => "chemical",
      "lack_of_protection" => "lack_of_protection",
      "other" => "other",
    }

    enum severity: {
      "level_1" => "level_1",
      "level_2" => "level_2",
      "level_3" => "level_3",
      "level_4" => "level_4",
    }

    enum level_of_uncertainty: {
      "low" => "low",
      "medium" => "medium",
      "high" => "high",
    }

    validates :hazard_type, inclusion: %w[mechanical size_and_shape electrical fire_and_explosion thermal ergonomic noise_and_vibration microbiological chemical lack_of_protection other], on: :choose_hazard_type
    validates :other_hazard_type, presence: true, if: -> { hazard_type == "other" }, on: :choose_hazard_type
    validates :description, presence: true, on: :choose_hazard_type
    validates :harm_scenario_steps, presence: true, on: :add_a_harm_scenario_and_probability_of_harm
    validates :too_many_harm_scenario_steps, inclusion: { in: [false], message: "Enter a maximum of #{MAX_HARM_SCENARIO_STEPS} steps" }
    validates :severity, inclusion: %w[level_1 level_2 level_3 level_4], on: :determine_severity_of_harm
    validates :multiple_casualties, inclusion: [true, false], on: :determine_severity_of_harm_casualties
    validates :level_of_uncertainty, inclusion: %w[low medium high], on: :add_uncertainty_and_sensitivity_analysis
    validates :sensitivity_analysis, inclusion: [true, false], on: :add_uncertainty_and_sensitivity_analysis

    before_save :clear_other_hazard_type
    before_save :set_confirmed_at

    def valid_for_completion?
      valid?(%i[choose_hazard_type add_a_harm_scenario_and_probability_of_harm determine_severity_of_harm determine_severity_of_harm_casualties add_uncertainty_and_sensitivity_analysis]) &&
        harm_scenario_steps.count.positive?
    end

    def confirmed?
      confirmed_at.present?
    end

  private

    def clear_other_hazard_type
      self.other_hazard_type = nil unless hazard_type == "other"
    end

    def set_confirmed_at
      self.confirmed_at = Time.zone.now if confirmed
    end
  end
end
