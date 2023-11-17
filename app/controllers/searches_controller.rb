class SearchesController < ApplicationController
  include InvestigationsHelper

  def show
    @search = SearchParams.new(query_params.except(:page_name))
    if @search.q.blank?
      if current_user.can_access_new_search?
        redirect_to notifications_path(query_params.except(:page_name))
      else
        redirect_to investigations_path(query_params.except(:page_name))
      end
    else
      @answer = notifications_search
      @investigations = @answer.includes([{ owner_team: :organisation, owner_user: :organisation }, :products])
    end
  end

private

  def notifications_search
    current_user.can_access_new_search? ? new_opensearch_for_investigations(20) : opensearch_for_investigations(20)
  end
end
