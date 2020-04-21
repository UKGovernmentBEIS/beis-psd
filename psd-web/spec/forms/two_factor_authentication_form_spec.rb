require "rails_helper"

RSpec.describe TwoFactorAuthenticationForm do
  subject(:form) { described_class.new(otp_code: otp_code, secondary_authentication_id: secondary_authentication.id) }

  let(:attempts) { 0 }
  let(:direct_otp_sent_at) { Time.new.utc }
  let(:secondary_authentication) { create(:secondary_authentication, attempts: attempts, direct_otp_sent_at: direct_otp_sent_at) }
  let(:otp_code) { secondary_authentication.direct_otp }


  describe "#valid?" do
    before { form.validate }

    context "when the two factor code is blank" do
      let(:otp_code) { "" }

      it "is not valid" do
        expect(form).to be_invalid
      end

      it "populates an error message" do
        expect(form.errors.full_messages_for(:otp_code)).to eq(["Enter the security code", "Incorrect security code"])
      end
    end

    context "when the two factor code contains letters" do
      let(:otp_code) { "123a5" }

      it "is not valid" do
        expect(form).to be_invalid
      end

      it "populates an error message" do
        expect(form.errors.full_messages_for(:otp_code)).to eq(["The code must be 5 numbers", "Incorrect security code"])
      end
    end

    context "when the two factor code has less digits than the required ones" do
      let(:otp_code) { rand.to_s[2..SecondaryAuthentication::OTP_LENGTH] }

      it "is not valid" do
        expect(form).to be_invalid
      end

      it "populates an error message" do
        expect(form.errors.full_messages_for(:otp_code)).to eq(["You haven’t entered enough numbers", "Incorrect security code"])
      end
    end


    context "when the two factor code has less digits than the required and contains letters" do
      let(:otp_code) { "1a" }

      it "is not valid" do
        expect(form).to be_invalid
      end

      it "populates an error message" do
        expect(form.errors.full_messages_for(:otp_code)).to eq(["The code must be 5 numbers", "Incorrect security code"])
      end
    end

    context "when the two factor code has more digits than the required ones" do
      let(:otp_code) { rand.to_s[2..SecondaryAuthentication::OTP_LENGTH + 2] }

      it "is not valid" do
        expect(form).to be_invalid
      end

      it "populates an error message" do
        expect(form.errors.full_messages_for(:otp_code)).to eq(["You’ve entered too many numbers", "Incorrect security code"])
      end
    end

    context "when maximum attempts were exceeded" do
      let(:attempts) { 11 }

      it "is not valid" do
        expect(form).to be_invalid
      end

      it "populates an error message" do
        expect(form.errors.full_messages_for(:otp_code)).to eq(["Too many attempts. New code sent"])
      end
    end

    context "when otp is expired" do
      let(:direct_otp_sent_at) { (SecondaryAuthentication::OTP_EXPIRY_SECONDS * 2).seconds.ago }

      it "is not valid" do
        expect(form).to be_invalid
      end

      it "populates an error message" do
        expect(form.errors.full_messages_for(:otp_code)).to eq(["Code expired. New code sent"])
      end
    end
  end
end
