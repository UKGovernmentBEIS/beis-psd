class RemoveProductIdFromPrismRiskAssessments < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :prism_risk_assessments, :product_id, :bigint
    end
  end
end
