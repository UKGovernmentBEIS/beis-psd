require "rails_helper"

RSpec.feature "PRISM triage", type: :feature do
  let(:prism_risk_assessment) { create(:prism_risk_assessment, :serious_risk) }

  scenario "visiting the start page" do
    visit prism.root_path

    expect(page).to have_text("Determine and evaluate the level of risk presented by a consumer product")
    expect(page).to have_link("Start now")

    expect(page).not_to have_link("Sign out")
  end

  scenario "selecting that a product poses a serious risk" do
    visit prism.serious_risk_path

    expect(page).to have_text("Is the product likely to pose a serious risk that would justify exemption from a full risk assessment?")

    click_button "Continue"

    expect(page).to have_text("Select whether the product poses a serious risk")

    choose "Yes"
    click_button "Continue"

    expect(page).to have_text("Are there any factors to indicate the product risk to be less than serious?")
  end

  scenario "selecting that a product does not pose a serious risk" do
    visit prism.serious_risk_path

    expect(page).to have_text("Is the product likely to pose a serious risk that would justify exemption from a full risk assessment?")

    choose "No"
    click_button "Continue"

    expect(page).to have_text("Does the product require a full risk assessment?")
  end

  scenario "selecting that a product does have rebuttable factors to posing a serious risk" do
    visit prism.serious_risk_rebuttable_path(prism_risk_assessment)

    expect(page).to have_text("Are there any factors to indicate the product risk to be less than serious?")

    click_button "Continue"

    expect(page).to have_text("Select whether there are any factors")

    choose "Yes"
    click_button "Continue"

    expect(page).to have_text("Enter a description")

    fill_in "risk_assessment[serious_risk_rebuttable_factors]", with: "Lorem ipsum"
    click_button "Continue"

    expect(page).to have_text("Does the product require a full risk assessment?")
  end

  scenario "selecting that a product does not have rebuttable factors to posing a serious risk" do
    visit prism.serious_risk_rebuttable_path(prism_risk_assessment)

    expect(page).to have_text("Are there any factors to indicate the product risk to be less than serious?")

    choose "No"
    click_button "Continue"

    expect(page).to have_text("Sign in")
  end

  scenario "selecting the product requires a full risk assessment" do
    visit prism.full_risk_assessment_required_path(prism_risk_assessment)

    expect(page).to have_text("Does the product require a full risk assessment?")

    click_button "Continue"

    expect(page).to have_text("Select whether the product requires a full risk assessment")

    choose "Yes"
    click_button "Continue"

    expect(page).to have_text("Sign in")
  end

  scenario "selecting the product may not require a full risk assessment" do
    visit prism.full_risk_assessment_required_path(prism_risk_assessment)

    choose "Not clear"
    click_button "Continue"

    expect(page).to have_text("Perform risk triage")
  end
end
