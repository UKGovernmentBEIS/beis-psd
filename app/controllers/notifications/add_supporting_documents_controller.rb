module Notifications
  class AddSupportingDocumentsController < ApplicationController
    include BreadcrumbHelper

    before_action :authenticate_user!
    before_action :set_notification
    before_action :validate_step
    before_action :set_document_form, only: [:show]
    before_action :set_remove_document, only: [:remove_upload]

    breadcrumb "notifications.label", :your_notifications

    def show
      render "add_supporting_documents"
    end

    def update
      @document_form = DocumentForm.new(document_form_params)
      @document_form.cache_file!(current_user)

      if save_document
        flash_and_redirect_success
      else
        render "add_supporting_documents"
      end
    end

    def remove_upload
      if request.delete?
        remove_document
        flash_and_redirect_removal_success
      else
        render "remove_upload"
      end
    end

  private

    def set_notification
      @notification = Investigation.find_by!(pretty_id: params[:notification_pretty_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def validate_step
      return true if action_name == "show" ? policy(@notification).view_non_protected_details? : (policy(@notification).update? && !@notification.is_closed?)

      render "errors/forbidden", status: :forbidden
      false
    end

    def set_document_form
      @document_form = DocumentForm.new
    end

    def set_remove_document
      @upload = @notification.documents.find(params[:upload_id])
    end

    def document_form_params
      params.require(:document_form).permit(:document, :title)
    end

    def save_document
      return false unless @document_form.valid?

      @document_form.cache_file!(current_user)
      @notification.documents.attach(@document_form.document)
      true
    end

    def flash_and_redirect_success
      flash[:success] = "Supporting document uploaded successfully"
      redirect_to notification_add_supporting_documents_path(@notification)
    end

    def remove_document
      @upload.destroy!
      true
    rescue StandardError => e
      Rails.logger.error("Failed to remove document: #{e.message}")
      false
    end

    def flash_and_redirect_removal_success
      flash[:success] = "Supporting document removed successfully"
      redirect_to notification_add_supporting_documents_path(@notification)
    end
  end
end
