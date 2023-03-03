require "rails_helper"

RSpec.describe MigrateMetadataForAuditTrails, :with_stubbed_mailer, :with_stubbed_opensearch, :with_test_queue_adapter do
  subject(:do_the_migration) { described_class.call }

  let(:product)  { create(:product) }
  let(:product2) { create(:product) }
  let(:product3) { create(:product) }

  context "with risk assessment added audit activity" do
    let(:investigation) { create(:allegation) }
    let(:risk_assessment) { create(:risk_assessment, investigation:) }
    let(:investigation_product) { create(:investigation_product, investigation:, product:) }

    let(:risk_assessment_added_audit_activity) do
      AuditActivity::RiskAssessment::RiskAssessmentAdded.create!(
        added_by_user: create(:user),
        investigation:,
        metadata: audit_activity_metadata,
        title: nil,
        body: nil
      )
    end

    let(:audit_activity_metadata) do
      {
        "risk_assessment" => risk_assessment.attributes.merge(
          "product_ids" => [investigation_product.product_id]
        )
      }
    end

    before do
      risk_assessment_added_audit_activity
    end

    it "migrates the metadata", :aggregate_failures do
      expect(risk_assessment_added_audit_activity.metadata.dig("risk_assessment", "investigation_product_ids")).to be_nil

      do_the_migration

      expect(risk_assessment_added_audit_activity.reload.metadata.dig("risk_assessment", "investigation_product_ids")).to eq([investigation_product.id])
    end
  end

  context "with risk assessment updated audit activity" do
    let(:investigation) { create(:allegation) }
    let(:risk_assessment) { create(:risk_assessment, investigation:) }
    let(:investigation_product1) { create(:investigation_product, investigation:, product:) }
    let(:investigation_product2) { create(:investigation_product, investigation:, product: product2) }

    let(:risk_assessment_added_audit_activity) do
      AuditActivity::RiskAssessment::RiskAssessmentUpdated.create!(
        added_by_user: create(:user),
        investigation:,
        metadata: audit_activity_metadata,
        title: nil,
        body: nil
      )
    end

    let(:audit_activity_metadata) do
      {
        "risk_assessment" => risk_assessment.attributes,
        "previous_product_ids" => [investigation_product1.product_id, investigation_product2.product_id],
      }
    end

    before do
      risk_assessment_added_audit_activity
    end

    it "migrates the metadata", :aggregate_failures do
      expect(risk_assessment_added_audit_activity.metadata["previous_investigation_product_ids"]).to be_nil

      do_the_migration

      expect(risk_assessment_added_audit_activity.reload.metadata["previous_investigation_product_ids"]).to eq([investigation_product1.id, investigation_product2.id])
    end
  end

  context "with accident or incident updated audit activity" do
    let(:investigation) { create(:allegation) }
    let(:accident_or_incident) { create(:accident_or_incident, investigation:) }
    let(:investigation_product) { create(:investigation_product, investigation:, product:) }

    let(:accident_or_incident_updated_audit_activity) do
      AuditActivity::AccidentOrIncident::AccidentOrIncidentUpdated.create!(
        added_by_user: create(:user),
        investigation:,
        metadata: audit_activity_metadata,
        title: nil,
        body: nil
      )
    end

    let(:audit_activity_metadata) do
      {
        "updates": {
          "product_id" => investigation_product.product_id
        }
      }
    end

    before do
      accident_or_incident_updated_audit_activity
    end

    it "migrates the metadata", :aggregate_failures do
      expect(accident_or_incident_updated_audit_activity.metadata.dig("updates", "investigation_product_id")).to be_nil

      do_the_migration

      expect(accident_or_incident_updated_audit_activity.reload.metadata.dig("updates", "investigation_product_id")).to eq(investigation_product.id)
    end
  end

  context "with corrective action updated activity" do
    let(:investigation) { create(:allegation) }
    let(:corrective_action) { create(:corrective_action, investigation:) }
    let(:investigation_product) { create(:investigation_product, investigation:, product:) }

    let(:corrective_action_updated_audit_activity) do
      AuditActivity::CorrectiveAction::Update.create!(
        added_by_user: create(:user),
        investigation:,
        investigation_product:,
        metadata: audit_activity_metadata,
        title: nil,
        body: nil
      )
    end

    let(:audit_activity_metadata) do
      {
        "updates": {
          "product_id" => investigation_product.product_id
        }
      }
    end

    before do
      corrective_action_updated_audit_activity
    end

    it "migrates the metadata", :aggregate_failures do
      expect(corrective_action_updated_audit_activity.metadata.dig("updates", "investigation_product_id")).to be_nil

      do_the_migration

      expect(corrective_action_updated_audit_activity.reload.metadata.dig("updates", "investigation_product_id")).to eq(investigation_product.id)
    end
  end
end
