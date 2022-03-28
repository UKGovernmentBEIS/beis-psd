require "rails_helper"

RSpec.describe "Export cases as XLSX file", :with_opensearch, :with_stubbed_notify, :with_stubbed_mailer, type: :request do
  let(:params) { { sort_by: "recent", case_type: "all", created_by: "all", case_status: "open", teams_with_access: "all" } }

  before do
    sign_in(user)
  end

  context "when logged in as a normal user" do
    let(:user) { create(:user, :activated, :viewed_introduction) }

    context "when generating a case export" do
      it "shows a forbidden error", :with_errors_rendered, :aggregate_failures do
        get generate_case_exports_path

        expect(response).to render_template("errors/forbidden")
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when viewing a case export" do
      it "shows a forbidden error", :with_errors_rendered, :aggregate_failures do
        case_export = CaseExport.create!(user:, params:)
        get case_export_path(case_export)

        expect(response).to render_template("errors/forbidden")
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  context "when logged in as a user with the all_data_exporter role" do
    let(:user) { create(:user, :activated, :all_data_exporter, :viewed_introduction) }

    context "when generating a case export" do
      it "allows user to generate a case export and redirects back to cases page" do
        get generate_case_exports_path

        expect(response).to have_http_status(:found)
      end
    end

    context "when viewing a case export" do
      it "allows user to view a case export download link" do
        case_export = CaseExport.create!(user:, params:)
        get case_export_path(case_export)

        expect(response).to have_http_status(:ok)
      end
    end

    # rubocop:disable RSpec/ExampleLength
    context "when downloading the export file" do
      let(:exported_data) do
        perform_enqueued_jobs
        get rails_storage_proxy_path(CaseExport.last.export_file)

        Tempfile.create("export_cases_spec", Rails.root.join("tmp"), encoding: "ascii-8bit") do |file|
          file.write response.body
          Roo::Excelx.new(file).sheet("Cases")
        end
      end

      it "treats formulas as text" do
        create(:allegation, description: "=A1")
        Investigation.import refresh: true, force: true

        get generate_case_exports_path, params: { q: "A1" }

        cell_a1 = exported_data.cell(1, 1)
        cell_with_formula_as_description = exported_data.cell(2, 5)

        aggregate_failures "cell value checks" do
          expect(cell_with_formula_as_description).to eq "=A1"
          expect(cell_with_formula_as_description).not_to eq cell_a1
          expect(cell_with_formula_as_description).not_to eq nil
        end
      end

      it "exports coronavirus flag" do
        create(:allegation, coronavirus_related: true)
        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        coronavirus_cell_title = exported_data.cell(1, 8)
        coronavirus_cell_content = exported_data.cell(2, 8)

        aggregate_failures "coronavirus cells values" do
          expect(coronavirus_cell_title).to eq "Coronavirus_Related"
          expect(coronavirus_cell_content).to eq "true"
        end
      end

      it "exports categories" do
        product_category = Faker::Hipster.unique.word
        category = Faker::Hipster.unique.word
        create(:allegation, product_category:, products: [create(:product, category:)])
        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        categories_cell_title = exported_data.cell(1, 6)
        categories_cell_content = exported_data.cell(2, 6)

        aggregate_failures "categories cells values" do
          expect(categories_cell_title).to eq "Product_Category"
          expect(categories_cell_content).to eq "#{product_category}, #{category}"
        end
      end

      it "exports the case risk level" do
        investigation = create(:allegation)
        ChangeCaseRiskLevel.call!(
          investigation:,
          user:,
          risk_level: (Investigation.risk_levels.values - %w[other]).sample
        )

        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        categories_cell_title = exported_data.cell(1, 9)
        categories_cell_content = exported_data.cell(2, 9)

        aggregate_failures "risk level cells values" do
          expect(categories_cell_title).to eq "Risk_Level"
          expect(categories_cell_content).to eq investigation.decorate.risk_level_description
        end
      end

      it "exports owner team and user" do
        user = create(:user)
        team = create(:team)
        case_with_team_owner = create(:allegation, creator: user)
        case_with_user_owner = create(:allegation, creator: user)

        ChangeCaseOwner.call!(investigation: case_with_team_owner, user:, owner: team)

        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        aggregate_failures do
          expect(exported_data.cell(1, 10)).to eq "Case_Owner_Team"
          expect(exported_data.cell(1, 11)).to eq "Case_Owner_User"

          expect(exported_data.cell(2, 1)).to eq case_with_team_owner.pretty_id
          expect(exported_data.cell(2, 10)).to eq team.name
          expect(exported_data.cell(2, 11)).to be_nil

          expect(exported_data.cell(3, 1)).to eq case_with_user_owner.pretty_id
          expect(exported_data.cell(3, 10)).to eq user.team.name
          expect(exported_data.cell(3, 11)).to eq user.name
        end
      end

      it "exports risk_assessments count" do
        create(:risk_assessment)

        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        aggregate_failures do
          expect(exported_data.cell(1, 19)).to eq "Risk_Assessments"
          expect(exported_data.cell(2, 19)).to eq "1"
        end
      end

      it "exports created_at and updated_at" do
        investigation = create(:allegation)

        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        aggregate_failures do
          expect(exported_data.cell(1, 20)).to eq "Date_Created"
          expect(exported_data.cell(1, 21)).to eq "Last_Updated"
          expect(exported_data.cell(2, 20)).to eq investigation.created_at.strftime("%Y-%m-%d %H:%M:%S %z")
          expect(exported_data.cell(2, 21)).to eq investigation.updated_at.strftime("%Y-%m-%d %H:%M:%S %z")
        end
      end

      it "exports risk_validated_at" do
        investigation = create(:allegation, risk_validated_at: Date.current)

        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        aggregate_failures do
          expect(exported_data.cell(1, 23)).to eq "Date_Validated"
          expect(exported_data.cell(2, 23)).to eq investigation.risk_validated_at.strftime("%Y-%m-%d %H:%M:%S %z")
        end
      end

      it "exports notifying_country" do
        create(:allegation)
        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        aggregate_failures do
          expect(exported_data.cell(1, 25)).to eq "Notifying_Country"
          expect(exported_data.cell(2, 25)).to eq "England"
        end
      end

      it "exports reported_as" do
        create(:allegation, reported_reason: "unsafe")
        Investigation.import refresh: true, force: true

        get generate_case_exports_path

        aggregate_failures do
          expect(exported_data.cell(1, 26)).to eq "Reported_as"
          expect(exported_data.cell(2, 26)).to eq "unsafe"
        end
      end

      context "when case does not have a creator_user" do
        it "exports Case_Creator_Team as nil" do
          creator_user = build(:user)
          allegation = create(:allegation, creator: creator_user)
          allow(allegation).to receive(:creator_user).and_return(nil)

          Investigation.import refresh: true, force: true

          get generate_case_exports_path

          aggregate_failures do
            expect(exported_data.cell(1, 24)).to eq "Case_Creator_Team"
            expect(exported_data.cell(2, 24)).to eq nil
          end
        end
      end

      context "when case has a creator user" do
        it "exports Case_Creator_Team" do
          team = create(:team)
          creator_user = create(:user, team:)
          create(:allegation, creator: creator_user)

          Investigation.import refresh: true, force: true

          get generate_case_exports_path

          aggregate_failures do
            expect(exported_data.cell(1, 24)).to eq "Case_Creator_Team"
            expect(exported_data.cell(2, 24)).to eq creator_user.team.name
          end
        end
      end

      context "when investigation is open" do
        it "date_closed column is empty" do
          create(:allegation)

          Investigation.import refresh: true, force: true

          get generate_case_exports_path

          aggregate_failures do
            expect(exported_data.cell(1, 22)).to eq "Date_Closed"
            expect(exported_data.cell(2, 22)).to eq nil
          end
        end
      end

      context "when investigation is closed" do
        it "date_closed column is empty" do
          closed_at_date = Date.new(2021, 1, 1)
          create(:allegation, is_closed: true, date_closed: closed_at_date)

          Investigation.import refresh: true, force: true

          get generate_case_exports_path, params: { case_status: "closed", format: :xlsx }

          aggregate_failures do
            expect(exported_data.cell(1, 22)).to eq "Date_Closed"
            expect(exported_data.cell(2, 22)).to eq closed_at_date.strftime("%Y-%m-%d %H:%M:%S %z")
          end
        end
      end
    end
    # rubocop:enable RSpec/ExampleLength
  end
end
