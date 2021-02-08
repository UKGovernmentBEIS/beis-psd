class AccidentOrIncidentTypeForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serialization

  attribute :event_type, :string, default: nil

  validates :event_type,
            inclusion: { in: ["accident", "incident"], message: I18n.t(".accident_or_incident_type_form.event_type.inclusion") }
end
