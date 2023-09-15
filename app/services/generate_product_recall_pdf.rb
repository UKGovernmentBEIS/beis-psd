class GenerateProductRecallPdf
  attr_reader :params, :product, :file

  def initialize(params, product, file)
    @params = params
    @product = product
    @file = file
  end

  def self.generate_pdf(params, product, file)
    new(params, product, file).generate_pdf
  end

  def generate_pdf
    metadata = {
      Title: "OPSS - #{title} - #{params['pdf_title']}",
      Author: product.owning_team&.name,
      Subject: title,
      Creator: "Product Safety Database",
      Producer: "Prawn",
      CreationDate: Time.zone.now
    }
    pdf = Prawn::Document.new(page_size: "A4", info: metadata)
    # rubocop:disable Rails/SaveBang
    pdf.font_families.update(
      "GDS Transport" => {
        normal: { file: Rails.root.join("app/assets/fonts/gds-transport-light.ttf"), font: "GDSTransport" },
        bold: { file: Rails.root.join("app/assets/fonts/gds-transport-bold.ttf"), font: "GDSTransport-Bold" },
      }
    )
    # rubocop:enable Rails/SaveBang
    pdf.font("GDS Transport")
    pdf.image(Rails.root.join("app/assets/images/opss-logo.jpg"), width: 120)
    pdf.text title, color: "FF0000", style: :bold, align: :right, size: 26
    pdf.table([
      [{ content: params["pdf_title"], colspan: 2, font_style: :bold }],
      [{ content: "Aspect", font_style: :bold }, { content: "Details", font_style: :bold }],
      *image_rows,
      [{ content: "Alert Number", font_style: :bold }, params["alert_number"]],
      [{ content: "Product Type", font_style: :bold }, params["product_type"]],
      [{ content: "Product Identifiers", font_style: :bold }, params["product_identifiers"]],
      [{ content: "Product Description", font_style: :bold }, params["product_description"]],
      [{ content: "Country of Origin", font_style: :bold }, country_from_code(params["country_of_origin"])],
      [{ content: "Counterfeit", font_style: :bold }, counterfeit],
      [{ content: "Risk Type", font_style: :bold }, params["risk_type"]],
      risk_level_row,
      [{ content: "Risk Description", font_style: :bold }, params["risk_description"]],
      [{ content: "Corrective Measures", font_style: :bold }, params["corrective_actions"]],
      [{ content: "Online Marketplace", font_style: :bold }, online_marketplace],
      [{ content: "Notifier", font_style: :bold }, product.owning_team&.name],
    ].compact, width: 522)
    pdf.text_box 'The OPSS Product Safety Alerts, Reports and Recalls Site can be accessed at the following link: <u><link href="https://www.gov.uk/guidance/product-recalls-and-alerts">https://www.gov.uk/guidance/product-recalls-and-alerts</link></u>', inline_format: true, at: [0, 50]
    pdf.render(file)
  end

private

  def product_safety_report?
    params["type"] == "product_safety_report"
  end

  def title
    product_safety_report? ? "Product Safety Report" : "Product Recall"
  end

  def image_rows
    if params["product_image_ids"].present?
      rows = [[{ content: "Images", font_style: :bold, rowspan: params["product_image_ids"].length }, image_cell(params["product_image_ids"].shift)]]
      params["product_image_ids"].each do |image|
        rows << [image_cell(image)]
      end
      rows
    end
  end

  def image_cell(id)
    document_upload = DocumentUpload.find_by(id:, upload_model: product)

    return if document_upload.blank?

    document_upload.file_upload.blob.open do |file|
      { image: File.open(file.path), fit: [200, 200] }
    end
  end

  def risk_level_row
    [{ content: "Risk Level", font_style: :bold }, params["risk_level"].presence || "Unknown"]
  end

  def country_from_code(code)
    country = Country.all.find { |c| c[1] == code }
    (country && country[0]) || code
  end

  def counterfeit
    return "Unknown" if params["counterfeit"].nil?

    params["counterfeit"] ? "Yes" : "No"
  end

  def online_marketplace
    return "N/A" if params["online_marketplace"].nil?
    return "No" unless params["online_marketplace"]

    "The listing has been removed by the online market place - #{params['other_marketplace_name'].presence || params['online_marketplace_id']}"
  end
end
