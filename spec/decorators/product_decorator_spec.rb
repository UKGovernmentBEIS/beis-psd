require "rails_helper"

RSpec.describe ProductDecorator, :with_stubbed_opensearch do
  subject(:decorated_product) { product.decorate }

  let(:product) { build(:product) }

  describe "#pretty_description" do
    specify { expect(decorated_product.pretty_description).to eq("Product: #{product.name}") }
  end

  describe "#summary_list" do
    include CountriesHelper

    let(:summary_list) { decorated_product.summary_list }

    context "when displaying the product summary" do
      it "displays the brand" do
        expect(summary_list).to summarise("Product brand", text: product.brand)
      end

      it "displays the Product name" do
        expect(summary_list).to summarise("Product name", text: product.name)
      end

      it "displays the Category" do
        expect(summary_list).to summarise("Category", text: product.category)
      end

      it "displays product authenticity" do
        expect(summary_list).to summarise("Product authenticity", text: I18n.t(product.authenticity, scope: Product.model_name.i18n_key))
      end

      it "displays the product marking" do
        expect(summary_list).to summarise("Product marking", text: decorated_product.markings)
      end

      it "displays the Barcode" do
        expect(summary_list).to summarise("Barcode", text: product.barcode)
      end

      it "displays the other product identifiers" do
        expect(summary_list).to summarise("Other product identifiers", text: product.product_code)
      end

      it "displays the Webpage" do
        expect(summary_list).to summarise("Webpage", text: product.webpage)
      end

      it "displays the Country of origin" do
        expect(summary_list).to summarise("Country of origin", text: country_from_code(product.country_of_origin))
      end

      it "displays the Description" do
        expect(summary_list).to summarise("Description", text: product.description)
      end
    end
  end

  describe "#description" do
    include_examples "a formated text", :product, :description
    include_examples "with a blank description", :product, :decorated_product
  end

  describe "#subcategory_and_category_label" do
    context "when both the Product sub-category and and category are present" do
      it "combines Product sub-category and product category" do
        expect(decorated_product.subcategory_and_category_label)
          .to eq("#{product.subcategory} (#{product.category.downcase})")
      end
    end

    context "when only the category is present" do
      before { product.subcategory = nil }

      it "returns only the product category" do
        expect(decorated_product.subcategory_and_category_label)
          .to eq(product.category)
      end
    end

    context "when only the Product subcategory is present" do
      before { product.category = nil }

      it "returns only the Product subcategory" do
        expect(decorated_product.subcategory_and_category_label)
          .to eq(product.subcategory)
      end
    end
  end

  describe "#markings" do
    context "when has_markings is nil" do
      before { product.has_markings = nil }

      it "returns a String" do
        expect(decorated_product.markings).to eq("Not provided")
      end
    end

    context "when has_markings == markings_unknown" do
      before { product.has_markings = "markings_unknown" }

      it "returns a String" do
        expect(decorated_product.markings).to eq("Unknown")
      end
    end

    context "when has_markings == markings_no" do
      before { product.has_markings = "markings_no" }

      it "returns a String" do
        expect(decorated_product.markings).to eq("None")
      end
    end

    context "when has_markings == markings_yes" do
      before do
        product.has_markings = "markings_yes"
        product.markings = %w[UKCA UKNI CE]
      end

      it "joins into a single String" do
        expect(decorated_product.markings).to eq("UKCA, UKNI, CE")
      end
    end

    context "when has_markings and markings are nil" do
      before do
        product.has_markings = nil
        product.markings = nil
      end

      it "returns a String" do
        expect(decorated_product.markings).to eq("Not provided")
      end
    end
  end
end
