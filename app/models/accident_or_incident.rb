class AccidentOrIncident < ApplicationRecord
  belongs_to :investigation
  has_many :products

  enum usage: {
    "during_normal_use" => "during_normal_use",
    "during_misuse" => "during_misuse",
    "with_adult_supervision" => "with_adult_supervision",
    "without_adult_supervision" => "without_adult_supervision",
    "unknown_usage" => "unknown_usage"
  }

  enum severity: {
    "serious" => "serious",
    "high" => "high",
    "medium" => "medium",
    "low" => "low",
    "unknown_severity" => "unknown_severity",
    "other" => "other"
  }

  enum type: {
    "accident" => "accident",
    "incident" => "incident"
  }
end
