module Investigations
  class CorrectiveActionsController < ApplicationController
    def show
      @investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id]).decorate
      authorize @investigation, :view_non_protected_details?
      @corrective_action = @investigation.corrective_actions.find(params[:id]).decorate
    end

    def edit
      @investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id]).decorate
      authorize @investigation, :update?
      @corrective_action = @investigation.corrective_actions.find!(params[:id]).decorate
      @file_blob = @corrective_action.documents_blobs.first || @corrective_action.documents_blobs.new
    end

    def update
      @investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id])
      authorize @investigation, :update?
      corrective_action = @investigation.corrective_actions.find(params[:id])

      service_form = UpdateCorrectiveActionForm.new(corrective_action_params)

      if service_form.invalid?
        @corrective_action = corrective_action.decorate
        return render :edit
      end

      corrective_action.assign_attributes(service_form.attributes)

      result = UpdateCorrectiveAction.call(
        corrective_action: corrective_action,
        file_description: service_form,
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
