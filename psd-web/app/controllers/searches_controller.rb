class SearchesController < ApplicationController
  include InvestigationsHelper

  def show
    set_search_params
    if @search.q.empty?
      redirect_to investigations_path(redirection_params)
    else
      @answer = search_for_investigations(20)
      @investigations = @answer.records(includes: [{ assignable: :organisation }, :products])
    end
  end
end
