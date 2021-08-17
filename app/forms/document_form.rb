class DocumentForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serialization
  include ActiveModel::Validations::Callbacks
  include ActiveModel::Dirty
  include SanitizationHelper

  attribute :title
  attribute :description
  attribute :existing_document_file_id
  attribute :document

  validates :title, presence: true
  validates :document, presence: true, if: -> { existing_document_file_id.blank? }
  validates :description, length: { maximum: 10_000 }
  validate :file_size_acceptable, if: -> { existing_document_file_id.blank? && document.present? }

  before_validation do
    trim_line_endings(:description)
  end

  def self.from(file)
    new(existing_document_file_id: file.signed_id, title: file.metadata[:title], description: file.metadata[:description])
  end

  def initialize(*args)
    super
    self.document ||= ActiveStorage::Blob.find_signed!(existing_document_file_id) if existing_document_file_id.present?
  end

  def cache_file!(user)
    if document.is_a?(ActiveStorage::Blob)
      document.metadata["title"] = title
      document.metadata["description"] = description
      document.metadata["updated"] = Time.zone.now
      document.save!
    elsif document
      self.document = ActiveStorage::Blob.create_and_upload!(
        io: document,
        filename: document.original_filename,
        content_type: document.content_type
      )

      document.update!(metadata: { title: title, description: description, created_by: user.id, updated: Time.zone.now })
      document.analyze_later

      self.existing_document_file_id = document.signed_id
    end
  end

private

  def file_size_acceptable
    return unless document.byte_size > max_file_byte_size

    errors.add(:base, :file_too_large, message: "File is too big, allowed size is #{max_file_byte_size / 1.megabyte} MB")
  end

  def max_file_byte_size
    100.megabytes
  end
end
