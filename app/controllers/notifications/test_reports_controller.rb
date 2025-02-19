module Notifications
  class TestReportsController < ApplicationController
    include BreadcrumbHelper

    before_action :set_notification
    before_action :validate_step, only: %i[show_with_notification_product]
    before_action :set_notification_product
    before_action :set_test_result, only: %i[show_with_notification_product_test update_with_notification_product_test]
    before_action :set_test_result_list, only: %i[show_with_notification_product update_with_notification_product]

    breadcrumb "notifications.label", :your_notifications

    def index; end

    def show_with_notification_product
      if params[:add_a_test_report_form].present?
        @add_another_test_report = AddTestReportsForm.new(add_another_test_report: params[:add_a_test_report_form][:add_another_test_report])
        @add_another_test_report.valid?
      else
        @add_another_test_report = AddTestReportsForm.new
      end

      if @existing_test_results.present?
        render :add_test_reports and return
      end

      @set_test_result_funding_on_case_form = SetTestResultFundingOnCaseForm.new
      render :add_test_reports_opss_funding
    end

    def update_with_notification_product
      @add_another_test_report = if params[:add_test_reports_form].present?
                                   AddTestReportsForm.new(add_test_report_params)
                                 else
                                   AddTestReportsForm.new
                                 end

      if params[:final].present?
        if @add_another_test_report.valid?
          if @add_another_test_report.add_another_test_report == "true"
            @set_test_result_funding_on_case_form = SetTestResultFundingOnCaseForm.new
            render :add_test_reports_opss_funding and return
          else
            return redirect_to notification_path(@notification)
          end
        else
          render :add_test_reports and return
        end
      end
      @set_test_result_funding_on_case_form = SetTestResultFundingOnCaseForm.new(opss_funding_params)

      if @set_test_result_funding_on_case_form.valid?
        @test_result = @notification.test_results.create!(investigation_product: @investigation_product)
        redirect_to with_product_testid_notification_test_reports_path(@notification, investigation_product_id: @investigation_product.id, test_report_id: @test_result.id, opss_funded: opss_funding_params[:opss_funded])
      else
        render :add_test_reports_opss_funding
      end
    end

    def show_with_notification_product_test
      if @test_result.tso_certificate_issue_date.present? || (params[:opss_funded] == "false") || params[:edit_test_report] == "true"
        @test_result_form = TestResultForm.from(@test_result)
        render :add_test_reports_details
      else
        @set_test_result_certificate_on_case_form = SetTestResultCertificateOnCaseForm.new
        render :add_test_reports_funding_details
      end
    end

    def update_with_notification_product_test
      if @test_result.tso_certificate_issue_date.present? || (params[:opss_funded] == "false") || params[:edit_test_report] == "true"
        flash_message = if params[:edit_test_report] == "true"
                          "Test report updated successfully."
                        else
                          "Test report uploaded successfully."
                        end
        @test_result_form = TestResultForm.new(test_details_params)
        @test_result_form.cache_file!(current_user)
        if @test_result_form.valid?
          UpdateTestResult.call!(
            investigation: @notification,
            investigation_product_id: @investigation_product.id,
            test_result: @test_result,
            legislation: @test_result_form.legislation,
            standards_product_was_tested_against: @test_result_form.standards_product_was_tested_against,
            result: @test_result_form.result,
            failure_details: @test_result_form.failure_details,
            details: @test_result_form.details,
            document: @test_result_form.document,
            date: @test_result_form.date,
            changes: @test_result_form.changes,
            user: current_user,
            silent: true
          )
          redirect_to with_product_notification_test_reports_path(@notification, investigation_product_id: @investigation_product.id), flash: { success: flash_message }
        else
          render :add_test_reports_details
        end
      else
        @set_test_result_certificate_on_case_form = SetTestResultCertificateOnCaseForm.new(opss_funding_details_params)

        if @set_test_result_certificate_on_case_form.valid?
          UpdateTestResult.call!(
            investigation: @notification,
            investigation_product_id: @investigation_product.id,
            test_result: @test_result,
            tso_certificate_reference_number: @set_test_result_certificate_on_case_form.tso_certificate_reference_number,
            tso_certificate_issue_date: @set_test_result_certificate_on_case_form.tso_certificate_issue_date,
            changes: {},
            user: current_user,
            silent: true
          )
          redirect_to with_product_testid_notification_test_reports_path(@notification, investigation_product_id: @investigation_product.id, test_report_id: @test_result.id, opss_funded: params[:opss_funded])
        else
          render :add_test_reports_funding_details
        end
      end
    end

  private

    def set_notification
      @notification = Investigation::Notification.includes(:owner_user, :owner_team, :creator_user, :creator_team).where(pretty_id: params[:notification_pretty_id]).first

      if @notification.nil?
        redirect_to "/404"
      else
        @notification
      end
    end

    def validate_step
      # Ensure objects exist
      unless @notification && current_user
        redirect_to "/404" and return
      end

      user_team = current_user.team

      # Check if the current user or their team is authorized to edit the notification
      authorized_to_edit =
        [@notification.creator_user, @notification.owner_user].include?(current_user) ||
        [@notification.owner_team, @notification.creator_team].include?(user_team) ||
        @notification.non_owner_teams_with_edit_access.include?(user_team)

      # Redirect if not authorized
      redirect_to "/403" unless authorized_to_edit
    end

    def set_notification_product
      @investigation_product = @notification.investigation_products.find(params[:investigation_product_id])
    end

    def opss_funding_params
      params.require(:set_test_result_funding_on_case_form).permit(:opss_funded)
    end

    def set_test_result
      @test_result = @test_result = @investigation_product.test_results.find(params[:test_report_id])
    end

    def opss_funding_details_params
      params.require(:set_test_result_certificate_on_case_form).permit(:tso_certificate_reference_number, tso_certificate_issue_date: %i[day month year])
    end

    def test_details_params
      params.require(:test_result_form).permit(:legislation, :standards_product_was_tested_against, :result, :failure_details, :details, :existing_document_file_id, :document, date: %i[day month year])
    end

    def add_test_report_params
      params.require(:add_test_reports_form).permit(:add_another_test_report)
    end

    def set_test_result_list
      @existing_test_results = @notification.test_results.where(investigation_product_id: @investigation_product.id).includes(investigation_product: :product)
    end
  end
end
