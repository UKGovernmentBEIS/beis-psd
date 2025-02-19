require "rails_helper"

RSpec.describe DocumentForm, :with_test_queue_adapter do
  subject(:form) { described_class.new(params) }

  let(:title) { Faker::Hipster.word }
  let(:description) { Faker::Lorem.paragraph }
  let(:new_document) { fixture_file_upload(file_fixture("testImage.png")) }
  let(:existing_document) do
    document = ActiveStorage::Blob.create_and_upload!(
      io: new_document,
      filename: new_document.original_filename,
      content_type: new_document.content_type
    )
    document.update!(metadata: { title:, description: })
    document
  end
  let(:document) { new_document }
  let(:existing_document_file_id) { existing_document.signed_id }

  let(:params) do
    {
      title:,
      description:,
      document:,
      existing_document_file_id:
    }
  end

  describe ".from" do
    subject(:form) { described_class.from(existing_document) }

    it "sets the existing_document_file_id attribute" do
      expect(form.existing_document_file_id).to eq(existing_document.signed_id)
    end

    it "sets the title attribute" do
      expect(form.title).to eq(title)
    end

    it "sets the description attribute" do
      expect(form.description).to eq(description)
    end
  end

  describe "validations" do
    let(:existing_document_file_id) { nil }

    before do
      form.cache_file!(create(:user))
    end

    context "with valid attributes" do
      it "is valid" do
        expect(form).to be_valid
      end
    end

    context "with blank title" do
      let(:title) { nil }

      it "is invalid" do
        expect(form).to be_invalid
      end
    end

    context "with blank document" do
      let(:document) { nil }

      context "when existing_document_file_id is supplied" do
        let(:existing_document_file_id) { existing_document.signed_id }

        it "is valid" do
          expect(form).to be_valid
        end
      end

      context "when existing_document_file_id is blank" do
        let(:existing_document_file_id) { nil }

        it "is invalid" do
          expect(form).to be_invalid
        end
      end
    end

    context "with long description" do
      let(:description) { "0" * 10_001 }

      it "is invalid" do
        expect(form).to be_invalid
      end
    end

    context "with file size validations" do
      context "with file larger than maximum size" do
        before do
          allow(form.document).to receive_messages(byte_size: 101.megabytes, image?: true)
        end

        it "is invalid" do
          expect(form).to be_invalid
          expect(form.errors[:base]).to include("Image file must be smaller than 100 MB in size")
        end
      end

      context "with file larger than maximum size (non-image)" do
        before do
          allow(form.document).to receive_messages(byte_size: 101.megabytes, image?: false)
        end

        it "is invalid" do
          expect(form).to be_invalid
          expect(form.errors[:base]).to include("File must be smaller than 100 MB in size")
        end
      end

      context "with empty file" do
        before do
          allow(form.document).to receive(:byte_size).and_return(0)
        end

        it "is invalid" do
          expect(form).to be_invalid
          expect(form.errors[:base]).to include("The selected file could not be uploaded – try again")
        end
      end

      context "with file within size limits" do
        before do
          allow(form.document).to receive(:byte_size).and_return(50.megabytes)
        end

        it "is valid" do
          expect(form).to be_valid
        end
      end
    end

    context "with antivirus validation" do
      context "when file is not yet scanned" do
        before do
          allow(form.document).to receive(:metadata).and_return({})
        end

        it "skips the validation" do
          expect(form).to be_valid
        end
      end

      context "when file is marked as safe" do
        before do
          allow(form.document).to receive(:metadata).and_return({ "safe" => true })
        end

        it "is valid" do
          expect(form).to be_valid
        end
      end

      context "when file is marked as unsafe" do
        before do
          allow(form.document).to receive(:metadata).and_return({ "safe" => false })
        end

        it "is invalid" do
          expect(form).to be_invalid
          expect(form.errors[:base]).to include("Files must be virus free")
        end
      end
    end
  end

  describe "#initialize" do
    context "when document is not supplied" do
      let(:document) { nil }

      it "populates the document by retrieving it from existing_document_file_id" do
        expect(form.document).to eq(existing_document)
      end
    end
  end

  describe "#cache_file!" do
    let(:existing_document_file_id) { nil }
    let(:user) { instance_double(User, id: "test") }

    context "with a new document" do
      it "creates the blob" do
        expect { form.cache_file!(user) }.to change(ActiveStorage::Blob, :count).by(1)
      end

      it "saves the document filename metadata" do
        form.cache_file!(user)
        expect(form.document.filename).to eq("testImage.png")
      end

      it "saves the document content_type metadata" do
        form.cache_file!(user)
        expect(form.document.content_type).to eq("image/png")
      end

      it "saves the document title metadata" do
        form.cache_file!(user)
        expect(form.document.metadata["title"]).to eq(title)
      end

      it "saves the document description metadata" do
        form.cache_file!(user)
        expect(form.document.metadata["description"]).to eq(description)
      end

      it "saves the document created_by metadata" do
        form.cache_file!(user)
        expect(form.document.metadata["created_by"]).to eq(user.id)
      end

      it "saves the document updated metadata" do
        freeze_time do
          form.cache_file!(user)
          expect(form.document.metadata["updated"].to_json).to eq(Time.zone.now.to_json)
        end
      end

      it "schedules the analyze job" do
        expect { form.cache_file!(user) }.to have_enqueued_job(ActiveStorage::AnalyzeJob)
      end

      it "sets existing_document_file_id" do
        form.cache_file!(user)
        expect(form.existing_document_file_id).to be_a(String)
      end
    end

    context "with an existing document" do
      let(:document) { existing_document }

      it "saves the document title metadata" do
        form.cache_file!(user)
        expect(form.document.metadata["title"]).to eq(title)
      end

      it "saves the document description metadata" do
        form.cache_file!(user)
        expect(form.document.metadata["description"]).to eq(description)
      end

      it "saves the document updated metadata" do
        freeze_time do
          form.cache_file!(user)
          expect(form.document.metadata["updated"].to_json).to eq(Time.zone.now.to_json)
        end
      end

      it "preserves the original created_by metadata" do
        original_created_by = form.document.metadata["created_by"]
        form.cache_file!(user)
        expect(form.document.metadata["created_by"]).to eq(original_created_by)
      end
    end

    context "with metadata handling" do
      it "handles empty description" do
        form.description = nil
        form.cache_file!(user)
        expect(form.document.metadata["description"]).to be_nil
      end

      it "handles line endings in description" do
        form.description = "Test\n\nDescription\n"
        form.cache_file!(user)
        expect(form.document.metadata["description"]).to eq("Test\n\nDescription\n")
      end
    end
  end
end
