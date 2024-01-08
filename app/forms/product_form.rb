class ProductForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks
  include ActiveModel::Serialization
  include SanitizationHelper

  attribute :id
  attribute :authenticity
  attribute :brand
  attribute :category
  attribute :country_of_origin
  attribute :description
  attribute :barcode
  attribute :name
  attribute :product_code
  attribute :subcategory
  attribute :webpage
  attribute :created_at, :datetime
  attribute :has_markings
  attribute :markings
  attribute :added_by_user_id
  attribute :when_placed_on_market
  attribute :document_upload_ids
  attribute :image_upload_ids
  attribute :ahoy_visit_id

  # Used when adding an image during product creation
  attribute :image
  attribute :existing_image_file_id

  # Used when creating a new product as part of the notification task list workflow
  attribute :notification_pretty_id

  before_validation { trim_line_endings(:description) }
  before_validation { trim_whitespace(:brand) }
  before_validation { nilify_blanks(:barcode, :brand) }

  validates :barcode, allow_nil: true, numericality: { only_integer: true }
  validates :barcode, allow_nil: true, length: { minimum: 5, maximum: 15 }, if: -> { barcode =~ /\A\d+\z/ }
  validates :authenticity, inclusion: { in: Product.authenticities.keys }
  validates :category, presence: true
  validates :subcategory, presence: true
  validates :name, presence: true
  validates :country_of_origin, presence: true
  validates :when_placed_on_market, presence: true
  validates :description, length: { maximum: 10_000 }

  validates :has_markings, inclusion: { in: Product.has_markings.keys }
  validate :markings_validity, if: -> { has_markings == "markings_yes" }

  def self.from(product)
    new(product.serializable_hash(except: %i[owning_team_id updated_at retired_at]))
  end

  def initialize(*args)
    super
    self.image ||= ActiveStorage::Blob.find_signed!(existing_image_file_id) if existing_image_file_id.present?
  end

  def cache_file!(user, product)
    if image.present?
      unless image.is_a?(ActiveStorage::Blob)
        self.image = ActiveStorage::Blob.create_and_upload!(
          io: image,
          filename: image.original_filename,
          content_type: image.content_type
        )

        image.analyze_later
      end

      self.existing_image_file_id = image.signed_id
    end

    if existing_image_file_id.present? && product.present?
      image_upload = ImageUpload.new(upload_model: product, created_by: user.id, file_upload: ActiveStorage::Blob.find_signed!(existing_image_file_id))
      image_upload.save!

      product.image_upload_ids.push(image_upload.id)
      product.save!
    end
  end

  def authenticity_not_provided?
    return false if id.nil?

    authenticity.nil?
  end

  def markings=(value)
    value ||= []
    super(value.uniq)
  end

  def markings
    return [] unless has_markings == "markings_yes"

    super
  end

  def authenticity_unsure?
    authenticity == "unsure"
  end

private

  def markings_validity
    if markings.blank? || !markings.all? { |value| Product::MARKINGS.include?(value) }
      errors.add(:markings, :blank)
    end
  end
end
