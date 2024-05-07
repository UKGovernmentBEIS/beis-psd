class NotificationExport < ApplicationRecord
  self.table_name = "case_exports"
  include CountriesHelper
  include InvestigationsHelper

  # Helps to manage the database query execution time within the PaaS imposed limits
  FIND_IN_BATCH_SIZE = 1000
  OPENSEARCH_PAGE_SIZE = 10_000

  belongs_to :user
  has_one_attached :export_file

  redacted_export_with :id, :created_at, :updated_at

  def params
    self[:params].deep_symbolize_keys
  end

  def export!
    raise "No notifications to export" unless notification_ids.length.positive?

    spreadsheet = to_spreadsheet.to_stream
    self.export_file = { io: spreadsheet, filename: "notifications_export.xlsx" }

    raise "No file attached" unless export_file.attached?

    save!
  end

  def to_spreadsheet
    package = Axlsx::Package.new
    sheet = package.workbook.add_worksheet name: "Notifications"

    add_header_row(sheet)

    notification_ids.each_slice(FIND_IN_BATCH_SIZE) do |batch_notification_ids|
      find_notifications(batch_notification_ids).each do |notification|
        sheet.add_row(serialize_notification(notification.decorate), types: :text)
      end
    end

    package
  end

  private

  def notification_ids
    return @notification_ids if @notification_ids

    @search = SearchParams.new(params)

    ids = []

    results = search_results

    while results.any?
      ids += results.pluck(:id)

      results = results.scroll
    end

    results.clear_scroll

    ids.sort
  end

  def search_results
    return new_opensearch_for_investigations(OPENSEARCH_PAGE_SIZE, user, scroll: true) if user.can_access_new_search?

    opensearch_for_investigations(OPENSEARCH_PAGE_SIZE, user, scroll: true)
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

  def add_header_row(sheet)
    sheet.add_row %w[ID
                     Status
                     Type
                     Title
                     Description
                     Product_Category
                     Reported_Reason
                     Risk_Level
                     Hazard_Type
                     Unsafe_Reason
                     Non_Compliant_Reason
                     Products
                     Businesses
                     Corrective_Actions
                     Tests
                     Risk_Assessments
                     Case_Owner_Team
                     Case_Creator_Team
                     Notifiers_Reference
                     Notifying_Country
                     Overseas_Regulator
                     Country
                     Trading_Standards_Region
                     Regulator_Name
                     OPSS_Internal_Team
                     Date_Created
                     Last_Updated
                     Date_Closed
                     Date_Validated]
  end

  def find_notifications(ids)
    Investigation
      .includes(:complainant, :products, :owner_team, :owner_user, { creator_user: :team })
      .find(ids)
  end

  def serialize_notification(notification)
    Pundit.policy!(user, notification).view_protected_details?(user:) || !notification.is_private? ? non_restricted_data(notification) : restricted_data(notification)
  end

  def non_restricted_data(notification)
    team = notification.creator_user&.team

    [
      notification.pretty_id,
      notification.is_closed? ? "Closed" : "Open",
      notification.type,
      notification.title,
      restrict_data_for_non_opss_user(notification.object.description),
      notification.categories.join(", "),
      notification.reported_reason,
      notification.risk_level_description,
      notification.hazard_type,
      notification.hazard_description,
      notification.non_compliant_reason,
      product_counts[notification.id] || 0,
      business_counts[notification.id] || 0,
      corrective_action_counts[notification.id] || 0,
      test_counts[notification.id] || 0,
      risk_assessment_counts[notification.id] || 0,
      notification.owner_team&.name,
      team&.name,
      notification.complainant_reference,
      country_from_code(notification.notifying_country, Country.notifying_countries),
      @notification.is_from_overseas_regulator ? "Yes" : "No",
      @notification.is_from_overseas_regulator ? "#{country_from_code(@notification.overseas_regulator_country)}" : "",
      team&.ts_region,
      team&.regulator_name,
      restrict_data_for_non_opss_user(team&.team_type == "internal"),
      notification.created_at,
      notification.updated_at,
      notification.date_closed,
      restrict_data_for_non_opss_user(notification.risk_validated_at),
    ]
  end

  def restrict_data_for_non_opss_user(field)
    user.is_opss? ? field : "Restricted"
  end

  def restricted_data(notification)
    team = notification.creator_user&.team

    [
      notification.pretty_id,
      notification.is_closed? ? "Closed" : "Open",
      notification.type,
      "Restricted",
      "Restricted",
      notification.categories.join(", "),
      notification.reported_reason,
      notification.risk_level_description,
      notification.hazard_type,
      notification.non_compliant_reason,
      notification.hazard_description,
      product_counts[notification.id] || 0,
      business_counts[notification.id] || 0,
      corrective_action_counts[notification.id] || 0,
      test_counts[notification.id] || 0,
      risk_assessment_counts[notification.id] || 0,
      notification.owner_team&.name,
      notification.creator_user&.team&.name,
      "Restricted",
      country_from_code(notification.notifying_country, Country.notifying_countries),
      @notification.is_from_overseas_regulator ? "Yes" : "No",
      @notification.is_from_overseas_regulator ? "#{country_from_code(@notification.overseas_regulator_country)}" : "",
      team&.ts_region,
      team&.regulator_name,
      (team&.team_type == "internal"),
      notification.created_at,
      notification.updated_at,
      notification.date_closed,
      notification.risk_validated_at
    ]
  end
end
