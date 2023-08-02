require "rails_helper"

RSpec.describe AuditActivity::Investigation::AddCase, :with_stubbed_mailer do
  let(:factory) { :case }

  it_behaves_like "an audit activity for investigation added"
end
