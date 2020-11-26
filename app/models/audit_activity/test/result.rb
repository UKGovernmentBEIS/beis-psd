class AuditActivity::Test::Result < AuditActivity::Test::Base
  def self.build_metadata(test_result)
    { test_result_id: test_result.id }
  end

  def self.from(_test_result)
    raise "Deprecated - use UpdateRiskAssessment.call instead"
  end

  # def self.date_label
  #   "Test date"
  # end

  # def email_update_text(viewer = nil)
  #   "Test result was added to the #{investigation.case_type} by #{source&.show(viewer)}."
  # end

  # # Returns the actual Test::Result record.
  # #
  # # This is a hack, as there is currently no direct association between the
  # # AuditActivity record and the test result record it is about. So the only
  # # way to retrieve this is by relying upon our current behaviour of attaching the
  # # same actual file to all of the AuditActivity, Investigation and Test records.
  # def test_result
  #   attachment.blob.attachments
  #     .find_by(record_type: "Test")
  #     &.record
  # end

private

  def subtitle_slug
    "Test result recorded"
  end
end
