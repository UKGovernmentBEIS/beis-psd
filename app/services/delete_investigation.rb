class DeleteInvestigation
  include Interactor

  delegate :investigation, :deleted_by, to: :context

  def call
    context.fail!(error: "No investigation supplied") unless investigation.is_a?(Investigation)

    ActiveRecord::Base.transaction do
      investigation.mark_as_deleted!
      investigation.update!(deleted_by: deleted_by.id)

      investigation.reload.__elasticsearch__.delete_document
    end
  end
end
