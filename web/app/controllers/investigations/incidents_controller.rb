class Investigations::IncidentsController < ApplicationController
  include Wicked::Wizard
  steps :details, :confirmation

  before_action :set_investigation
  before_action :build_incident

  # GET investigations/1/incidents/new
  def new;
    session[:incident] = {}
    redirect_to wizard_path(steps.first, request.query_parameters)
  end

  # GET investigations/1/incidents/step
  def show
    @incident = @investigation.incidents.build(session[:incident])
    render_wizard
  end

  # PUT investigations/1/incidents/step
  def update
    session[:incident] = @incident.attributes
    if !@incident.valid?(step)
      render step
    else
      redirect_to next_wizard_path if step != steps.last
      create if step == steps.last
    end
  end

  # POST investigations/1/incidents
  def create
    @incident = @investigation.incidents.build(session[:incident])
    if @incident.errors.empty? && @incident.save
      redirect_to investigation_url(@investigation), notice: "Incident was successfully recorded."
    else
      render step
    end
  end

private

  def build_incident
    if params.include? :incident
      @incident = @investigation.incidents.build(incident_params)
    else
      @incident = @investigation.incidents.build
    end
  end

  def set_investigation
    @investigation = Investigation.find(params[:investigation_id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def incident_params
    params.require(:incident).permit(:incident_type,
                                     :description,
                                     :affected_party,
                                     :location,
                                     :day,
                                     :month,
                                     :year)
  end
end
