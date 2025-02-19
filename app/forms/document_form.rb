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

  validates :document, presence: true, if: -> { existing_document_file_id.blank? }
  validate :file_size_below_max, if: -> { document.present? && existing_document_file_id.present? }
  validate :file_size_above_min, if: -> { document.present? && existing_document_file_id.present? }
  validate :file_is_free_of_viruses, if: -> { document.present? && existing_document_file_id.present? }
  validates :title, presence: true
  validates :description, length: { maximum: 10_000 }

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
    return if document.nil? || document.blank?

    if document.is_a?(ActiveStorage::Blob)
      document.metadata["title"] = title
      document.metadata["description"] = description
      document.metadata["updated"] = Time.zone.now
      document.save!
    elsif document.instance_of?(String)
      return if document.blank?

      self.document = ActiveStorage::Blob.find(document)
      document.update!(metadata: { title:, description:, created_by: user.id, updated: Time.zone.now })
    elsif document
      self.document = ActiveStorage::Blob.create_and_upload!(
        io: document,
        filename: document.original_filename,
        content_type: document.content_type
      )

      document.update!(metadata: { title:, description:, created_by: user.id, updated: Time.zone.now })
      document.analyze_later

      self.existing_document_file_id = document.signed_id
    end
  end

private

  def file_size_below_max
    return unless document.byte_size > max_file_byte_size

    file_type = document.image? ? "Image file" : "File"

    errors.add(:base, :file_too_large, message: "#{file_type} must be smaller than #{max_file_byte_size / 1.megabyte} MB in size")
  end

  def file_size_above_min
    return unless document.byte_size < min_file_byte_size

    # using an error that assumes that the upload has failed, rather than that the user has tried to upload an empty file.
    errors.add(:base, :upload_failed, message: "The selected file could not be uploaded – try again")
  end

  def max_file_byte_size
    100.megabytes
  end

  def min_file_byte_size
    1.byte
  end

  def file_is_free_of_viruses
    # don't run this validation unless document has been analyzed by antivirus analyzer
    return unless document.metadata.key?("safe")

    return if document.metadata["safe"] == true

    errors.add(:base, :virus, message: "Files must be virus free")
  end
end
