# This migration comes from prism (originally 20230719134900)
class AddProbabilityEvidenceDescriptionToPrismHarmScenarioSteps < ActiveRecord::Migration[7.0]
  def change
    add_column :prism_harm_scenario_steps, :probability_evidence_description, :text
  end
end
