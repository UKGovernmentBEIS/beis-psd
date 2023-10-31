class CaseExport < ApplicationRecord
  include CountriesHelper
  include InvestigationsHelper

  # Helps to manage the database query execution time within the PaaS imposed limits
  FIND_IN_BATCH_SIZE = 1000

  belongs_to :user
  has_one_attached :export_file

  redacted_export_with :id, :created_at, :updated_at

  def params
    self[:params].deep_symbolize_keys
  end

  def export!
    raise "No cases to export" unless case_ids.length.positive?

    spreadsheet = to_spreadsheet.to_stream
    self.export_file = { io: spreadsheet, filename: "cases_export.xlsx" }

    raise "No file attached" unless export_file.attached?

    save!
  end

  def to_spreadsheet
    package = Axlsx::Package.new
    sheet = package.workbook.add_worksheet name: "Cases"

    add_header_row(sheet)

    case_ids.each_slice(FIND_IN_BATCH_SIZE) do |batch_case_ids|
      find_cases(batch_case_ids).each do |investigation|
        sheet.add_row(serialize_case(investigation.decorate), types: :text)
      end
    end

    package
  end

private

  def case_ids
    return @case_ids if @case_ids

    @search = SearchParams.new(params)
    current_page = opensearch_for_investigations(10000, user)

    ids = current_page.results.pluck(:id)

    while !current_page.last_page?
      current_page = current_page.next_page

      ids += current_page.results.pluck(:id)
    end

    ids.sort
  end

  def activity_counts
    @activity_counts ||= Activity.group(:investigation_id).count
  end

  def business_counts
    @business_counts ||= InvestigationBusiness.unscoped.group(:investigation_id).count
  end

  def product_counts
    @product_counts ||= InvestigationProduct.unscoped.group(:investigation_id).count
  end

  def corrective_action_counts
    @corrective_action_counts ||= CorrectiveAction.group(:investigation_id).count
  end

  def correspondence_counts
    @correspondence_counts ||= Correspondence.group(:investigation_id).count
  end

  def test_counts
    @test_counts ||= Test.group(:investigation_id).count
  end

  def risk_assessment_counts
    @risk_assessment_counts ||= RiskAssessment.group(:investigation_id).count
  end

  def team_mappings
    @team_mappings ||= JSON.load_file!(Rails.root.join("app/assets/team-mappings.json"), object_class: OpenStruct)
  end

  def team_data(team_name)
    # Returns an `OpenStruct` with all nils to avoid having presence checks later
    team_mappings.find { |team| team.team_name == team_name } ||
      OpenStruct.new(team_name: nil, type: nil, regulator_name: nil, ts_region: nil, ts_acronym: nil, ts_area: nil)
  end

  def add_header_row(sheet)
    sheet.add_row %w[ID
                     Status
                     Title
                     Type
                     Description
                     Product_Category
                     Hazard_Type
                     Coronavirus_Related
                     Risk_Level
                     Case_Owner_Team
                     Case_Owner_User
                     Source_Type
                     Products
                     Businesses
                     Activities
                     Correspondences
                     Corrective_Actions
                     Tests
                     Risk_Assessments
                     Date_Created
                     Last_Updated
                     Date_Closed
                     Date_Validated
                     Case_Creator_Team
                     Notifying_Country
                     Reported_Reason
                     Complainant_Reference
                     Case_Type
                     Trading_Standards_Region
                     Trading_Standards_Region_Code
                     Regulator_Name
                     OPSS_Internal_Team
                     Non_Compliant_Reason]
  end

  def find_cases(ids)
    Investigation
        .includes(:complainant, :products, :owner_team, :owner_user, { creator_user: :team })
        .find(ids)
  end

  def serialize_case(investigation)
    Pundit.policy!(user, investigation).view_protected_details?(user:) || !investigation.is_private? ? non_restricted_data(investigation) : restricted_data(investigation)
  end

  def non_restricted_data(investigation)
    team_data = team_data(investigation.creator_user&.team&.name)

    [
      investigation.pretty_id,
      investigation.is_closed? ? "Closed" : "Open",
      investigation.title,
      investigation.type,
      investigation.object.description,
      investigation.categories.join(", "),
      investigation.hazard_type,
      investigation.coronavirus_related?,
      investigation.risk_level_description,
      investigation.owner_team&.name,
      investigation.owner_user&.name,
      investigation.complainant&.complainant_type,
      product_counts[investigation.id] || 0,
      business_counts[investigation.id] || 0,
      activity_counts[investigation.id] || 0,
      correspondence_counts[investigation.id] || 0,
      corrective_action_counts[investigation.id] || 0,
      test_counts[investigation.id] || 0,
      risk_assessment_counts[investigation.id] || 0,
      investigation.created_at,
      investigation.updated_at,
      investigation.date_closed,
      investigation.risk_validated_at,
      investigation.creator_user&.team&.name,
      country_from_code(investigation.notifying_country, Country.notifying_countries),
      investigation.reported_reason,
      investigation.complainant_reference,
      investigation.case_type,
      team_data.ts_region,
      team_data.ts_acronym,
      team_data.regulator_name,
      (team_data.type == "internal"),
      investigation.non_compliant_reason
    ]
  end

  def restricted_data(investigation)
    team_data = team_data(investigation.creator_user&.team&.name)

    [
      investigation.pretty_id,
      investigation.is_closed? ? "Closed" : "Open",
      "Restricted",
      investigation.type,
      "Restricted",
      investigation.categories.join(", "),
      investigation.hazard_type,
      investigation.coronavirus_related?,
      investigation.risk_level_description,
      investigation.owner_team&.name,
      "Restricted",
      investigation.complainant&.complainant_type,
      product_counts[investigation.id] || 0,
      business_counts[investigation.id] || 0,
      activity_counts[investigation.id] || 0,
      correspondence_counts[investigation.id] || 0,
      corrective_action_counts[investigation.id] || 0,
      test_counts[investigation.id] || 0,
      risk_assessment_counts[investigation.id] || 0,
      investigation.created_at,
      investigation.updated_at,
      investigation.date_closed,
      investigation.risk_validated_at,
      investigation.creator_user&.team&.name,
      country_from_code(investigation.notifying_country, Country.notifying_countries),
      investigation.reported_reason,
      "Restricted",
      investigation.case_type,
      team_data.ts_region,
      team_data.ts_acronym,
      team_data.regulator_name,
      (team_data.type == "internal")
    ]
  end
end
