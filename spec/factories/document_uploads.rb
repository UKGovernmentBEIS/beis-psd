FactoryBot.define do
  trait :with_document_upload_document_info do
    transient do
      document_file { Rails.root.join("test/fixtures/files/test_result.txt") }
      document_title { Faker::Lorem.sentence }
      document_description { Faker::Lorem.paragraph }
    end
  end

  trait :with_document_upload_image_info do
    transient do
      document_file { Rails.root.join("test/fixtures/files/testImage.png") }
      document_title { Faker::Lorem.sentence }
      document_description { Faker::Lorem.paragraph }
    end
  end

  trait :with_document_upload do
    with_document_upload_document_info

    after :create do |model, evaluator|
      file = ActiveSupportHelper.create_file(
        model,
        evaluator,
        metadata: {}
      )

      document_upload = DocumentUpload.create!(
        upload_model: model,
        file_upload: file,
        title: evaluator.document_title,
        description: evaluator.document_description
      )

      model.update!(document_upload_ids: [document_upload.id])
    end
  end

  trait :with_antivirus_checked_document_upload do
    with_document_upload_document_info

    after :create do |model, evaluator|
      file = ActiveSupportHelper.create_file(
        model,
        evaluator,
        metadata: {
          analyzed: true,
          identified: true,
          safe: true
        }
      )

      document_upload = DocumentUpload.create!(
        upload_model: model,
        file_upload: file,
        title: evaluator.document_title,
        description: evaluator.document_description
      )

      model.update!(document_upload_ids: [document_upload.id])
    end
  end

  trait :with_antivirus_checked_image_document_upload do
    with_document_upload_image_info

    after :create do |model, evaluator|
      file = ActiveSupportHelper.create_file(
        model,
        evaluator,
        metadata: {
          analyzed: true,
          identified: true,
          safe: true
        }
      )

      document_upload = DocumentUpload.create!(
        upload_model: model,
        file_upload: file,
        title: evaluator.document_title,
        description: evaluator.document_description
      )

      model.update!(document_upload_ids: [document_upload.id])
    end
  end

  factory :document_upload do
    transient do
      notification { create(:notification) }
    end

    title { Faker::Lorem.sentence }
    description { Faker::Lorem.paragraph }

    after(:build) do |document_upload, evaluator|
      document_upload.upload_model = evaluator.notification
      document_upload.file_upload.attach(
        io: File.open(Rails.root.join("test/fixtures/files/test_result.txt")),
        filename: "test_result.txt",
        content_type: "text/plain"
      )
    end
  end
end
