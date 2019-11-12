class Investigation < ApplicationRecord
  class Project < Investigation
    validates :user_title, :description, presence: true

    index_name [ENV.fetch("ES_NAMESPACE", "default_namespace"), Rails.env, "investigations"].join("_")

    def case_type
      "project"
    end

  private

    def create_audit_activity_for_case
      AuditActivity::Investigation::AddProject.from(self.decorate)
    end
  end
end
