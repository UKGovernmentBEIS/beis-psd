module Investigations
  class CorrectiveActionsController < ApplicationController
    def new
      investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id])
      authorize investigation, :view_non_protected_details?
      @corrective_action_form = CorrectiveActionForm.new
      @investigation = investigation.decorate
    end

    def create
      investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id])
      authorize investigation, :view_non_protected_details?

      @corrective_action_form = CorrectiveActionForm.new(corrective_action_params)

      @investigation = investigation.decorate
      return render :new if @corrective_action_form.invalid?

      result = AddCorrectiveActionToCase.call(
        @corrective_action_form
          .serializable_hash
          .merge(user: current_user, investigation: investigation)
      )

      if result.success?
        return redirect_to investigation_corrective_action_path(@investigation, result.corrective_action), flash: { success: "Corrective action was successfully recorded." }
      end

      render :new
    end

    def show
      @investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id]).decorate
      authorize @investigation, :view_non_protected_details?
      @corrective_action = @investigation.corrective_actions.find(params[:id]).decorate
    end

    def edit
      investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id])
      authorize investigation, :update?
      corrective_action = investigation.corrective_actions.find(params[:id])
      @corrective_action_form = CorrectiveActionForm.from(corrective_action)

      @file_blob = corrective_action.document_blob
      @investigation = investigation.decorate
    end

    def update
      investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id])
      authorize investigation, :update?

      corrective_action       = investigation.corrective_actions.find(params[:id])
      @corrective_action_form = CorrectiveActionForm.from(corrective_action)
      @investigation          = investigation.decorate

      @corrective_action_form.assign_attributes(corrective_action_params)

      return render :edit if @corrective_action_form.invalid?

      result = UpdateCorrectiveAction.call(
        @corrective_action_form
          .serializable_hash
          .merge(
            user: current_user,
            corrective_action: corrective_action,
            changes: @corrective_action_form.changes
          )
      )

      return redirect_to investigation_corrective_action_path(investigation, result.corrective_action) if result.success?

      render :edit
    end

  private

    def corrective_action_params
      params.require(:corrective_action).permit(
        :product_id,
        :business_id,
        :legislation,
        :action,
        :has_online_recall_information,
        :details,
        :related_file,
        :measure_type,
        :duration,
        :geographic_scope,
        :other_action,
        file: %i[file description],
        date_decided: %i[day month year]
      )
    end
  end
end
