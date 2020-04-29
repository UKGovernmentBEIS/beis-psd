class Investigations::AssignController < ApplicationController
  include Wicked::Wizard
  before_action :set_investigation
  before_action :potential_owner, only: %i[show create]
  before_action :store_assignee, only: %i[update]

  steps :choose, :confirm_assignment_change

  def show
    @potential_owner = potential_owner
    render_wizard
  end

  def new
    clear_session
    redirect_to wizard_path(steps.first, request.query_parameters)
  end

  def update
    if assignee_valid?
      redirect_to next_wizard_path
    else
      render_wizard
    end
  end

  def create
    @investigation.owner = potential_owner
    @investigation.assignee_rationale = params[:investigation][:assignee_rationale]
    @investigation.save
    redirect_to investigation_path(@investigation), notice: "#{@investigation.case_type.upcase_first} was successfully updated."
  end

private

  def clear_session
    session[:owner_id] = nil
  end

  def set_investigation
    investigation = Investigation.find_by!(pretty_id: params[:investigation_pretty_id])
    authorize investigation, :show?
    @investigation = investigation.decorate
  end

  def assignee_params
    params[:investigation][:owner_id] = case params[:investigation][:owner_id]
                                        when "someone_in_your_team"
                                          params[:investigation][:select_team_member]
                                        when "previously_assigned"
                                          params[:investigation][:select_previously_assigned]
                                        when "other_team"
                                          params[:investigation][:select_other_team]
                                        when "someone_else"
                                          params[:investigation][:select_someone_else]
                                        else
                                          params[:investigation][:owner_id]
                                        end
    params.require(:investigation).permit(:owner_id)
  end

  def store_assignee
    session[:owner_id] = assignee_params[:owner_id]
  end

  def assignee_valid?
    if step == :choose
      if potential_owner == nil
        @investigation.errors.add(:owner_id, :invalid, message: "Select case owner")
      end
    end
    @investigation.errors.empty?
  end

  def potential_owner
    User.find_by(id: session[:owner_id]) || Team.find_by(id: session[:owner_id])
  end
end
