module Investigations
  class CorrectiveActionsController < ApplicationController
    include FileConcern
    set_attachment_names :file
    set_file_params_key :corrective_action

    def show
      @investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id]).decorate
      authorize @investigation, :view_non_protected_details?
      @corrective_action = @investigation.corrective_actions.find(params[:id]).decorate
    end

    def edit
      @investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id]).decorate
      authorize @investigation, :update?
      @corrective_action = @investigation.corrective_actions.find(params[:id]).decorate

      @service_form = UpdateCorrectiveActionForm.new(@corrective_action.attributes)

      @file_blob = @corrective_action.documents_blobs.first || @corrective_action.documents_blobs.new
    end

    def update
      @investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id])
      authorize @investigation, :update?

      corrective_action = @investigation.corrective_actions.find(params[:id])

      previous_documents = corrective_action.documents
      result = UpdateCorrectiveAction.call(
        corrective_action: corrective_action,
        corrective_action_params: corrective_action_params,
        new_file: corrective_action_params.dig(:file),
        new_file_description: previous_documents,
        user: current_user
      )
      return redirect_to investigation_action_path(@investigation, result.corrective_action) if result.success?

      @corrective_action = corrective_action.decorate
      render :edit
    end

  private

    def corrective_action_params
      params.require(:corrective_action).permit(
        :product_id,
        :business_id,
        :legislation,
        :summary,
        :details,
        :related_file,
        :measure_type,
        :duration,
        :geographic_scope,
        file: %i[file description],
        date_decided: %i[day month year]
      )
    end
  end
end
