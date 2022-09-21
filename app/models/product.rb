class Product < ApplicationRecord
  include CountriesHelper
  include Documentable
  include Searchable
  include AttachmentConcern

  self.ignored_columns = ["batch_number", "customs_code", "number_of_affected_units", "affected_units_status"]

  enum authenticity: {
    "counterfeit" => "counterfeit",
    "genuine" => "genuine",
    "unsure" => "unsure"
  }

  enum affected_units_status: {
    "exact" => "exact",
    "approx" => "approx",
    "unknown" => "unknown",
    "not_relevant" => "not_relevant"
  }

  enum has_markings: {
    "markings_yes" => "markings_yes",
    "markings_no" => "markings_no",
    "markings_unknown" => "markings_unknown"
  }

  enum when_placed_on_market: {
    "before_2021" => "before_2021",
    "on_or_after_2021" => "on_or_after_2021",
    "unknown_date" => "unknown_date"
  }

  MARKINGS = %w[UKCA UKNI CE].freeze

  index_name [ENV.fetch("OS_NAMESPACE", "default_namespace"), Rails.env, "products"].join("_")

  settings do
    mappings do
      indexes :name_for_sorting, type: :keyword
    end
  end

  def as_indexed_json(*)
    as_json(
      include: {
        investigations: {
          only: %i[hazard_type is_closed],
          methods: :owner_id
        }
      },
      methods: %i[tiebreaker_id name_for_sorting psd_ref]
    )
  end

  has_many_attached :documents

  has_many :investigation_products, dependent: :destroy
  has_many :investigations, through: :investigation_products

  has_many :corrective_actions, dependent: :destroy
  has_many :tests, dependent: :destroy
  has_many :test_results, class_name: "Test::Result", dependent: :destroy
  has_many :unexpected_events
  has_many :risk_assessed_products
  has_many :risk_assessments, through: :risk_assessed_products

  has_one :source, as: :sourceable, dependent: :destroy

  belongs_to :owning_team, class_name: "Team", inverse_of: :owned_products, optional: true

  redacted_export_with :id, :affected_units_status, :authenticity, :barcode, :batch_number,
                       :brand, :category, :country_of_origin, :created_at, :customs_code, :description,
                       :has_markings, :markings, :name, :number_of_affected_units, :product_code,
                       :subcategory, :updated_at, :webpage, :when_placed_on_market, :owning_team_id

  def supporting_information
    tests + corrective_actions + unexpected_events + risk_assessments
  end

  def images
    documents.includes(:blob).joins(:blob).where("left(content_type, 5) = 'image'")
  end

  def non_image_documents
    documents.includes(:blob).joins(:blob).where("left(content_type, 5) != 'image'")
  end

  def virus_free_images
    images.joins(:blob).where("active_storage_blobs.metadata LIKE ?", '%"safe":true%')
  end

  def virus_free_non_image_attachments
    non_image_documents.joins(:blob).where("active_storage_blobs.metadata LIKE ?", '%"safe":true%')
  end

  def name_for_sorting
    name
  end

  def psd_ref
    "psd-#{id}"
  end
end
