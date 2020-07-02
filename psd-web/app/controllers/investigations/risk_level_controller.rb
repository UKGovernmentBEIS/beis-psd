module Investigations
  class RiskLevelController < ApplicationController
    def show
      @investigation = Investigation.find_by!(pretty_id: params.require(:investigation_pretty_id)).decorate
      authorize @investigation, :update?
      @risk_level_form = RiskLevelForm.new(risk_level: @investigation.risk_level)
    end

    def update
      @investigation = Investigation.find_by!(pretty_id: params.require(:investigation_pretty_id)).decorate
      authorize @investigation, :update?
      @risk_level_form = RiskLevelForm.new(params.require(:investigation).permit(:risk_level, :risk_level_other))
      return render :show unless @risk_level_form.valid?

      result = ChangeCaseRiskLevel.call(investigation: @investigation, risk_level: @risk_level_form.risk_level.presence)
      if result.success?
        flash[:success] = I18n.t(".success", scope: "investigations.risk_level", action: result.change_action, case_type: @investigation.case_type)
        redirect_to investigation_path(@investigation)
      else
        flash[:error] = I18n.t(".error", scope: "investigations.risk_level", action: result.change_action)
        render :show
      end
    end
  end
end
