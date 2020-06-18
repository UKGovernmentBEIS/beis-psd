module Investigations
  class SupportingInformationController < ApplicationController
    def index
      authorize investigation, :view_non_protected_details?
      set_breadcrumbs

      @supporting_information       = @investigation.supporting_information.map(&:decorate)
      @other_supporting_information = @investigation.generic_supporting_information_attachments.decorate
    end

    def new
      authorize investigation, :update?
      set_breadcrumbs
      supporting_information_form
    end

    def create
      authorize investigation, :update?
      set_breadcrumbs
      return render(:new) if supporting_information_form.invalid?

      case supporting_information_form.type
      when "comment"
        redirect_to new_investigation_activity_comment_path(@investigation)
      when "corrective_action"
        redirect_to new_investigation_corrective_action_path(@investigation)
      when "correspondence"
        redirect_to new_investigation_correspondence_path(@investigation)
      when "image", "generic_information"
        redirect_to new_investigation_new_path(@investigation)
      when "testing_result"
        redirect_to new_result_investigation_tests_path(@investigation)
      end
    end

  private

    def investigation
      @investigation ||= Investigation
                        .find_by!(pretty_id: params[:investigation_pretty_id])
                        .decorate
    end

    def set_breadcrumbs
      @breadcrumbs = {
        items: [
          { text: "Cases", href: investigations_path(previous_search_params) },
          { text: @investigation.pretty_description }
        ]
      }
    end

    def supporting_information_form
      @supporting_information_form ||= SupportingInformationForm.new(type: params[:type])
    end
  end
end
