class NotificationsController < ApplicationController
  include InvestigationsHelper
  include BreadcrumbHelper

  before_action :set_search_params, only: %i[index]
  before_action :set_last_case_view_cookie, only: %i[index]
  before_action :set_notification, except: %i[index your_notifications team_notifications assigned_notifications]

  breadcrumb "notifications.label", :your_notifications

  # GET /notifications
  def index
    # Find the most recent incomplete bulk products upload for the current user, if any
    @incomplete_bulk_products_upload = BulkProductsUpload.where(user: current_user, submitted_at: nil).order(updated_at: :desc).first

    @pagy, @answer  = pagy_searchkick(new_opensearch_for_investigations(20, paginate: true))
    @count          = count_to_display
    @investigations = InvestigationDecorator
                        .decorate_collection(@answer.includes([{ owner_user: :organisation, owner_team: :organisation }, :products]))
    @page_name = "all_cases"
  end

  # GET /notifications/your-notifications
  def your_notifications
    return redirect_to your_cases_investigations_path unless current_user.can_use_notification_task_list?

    @page_name = "your_cases"
    @search = SearchParams.new(
      {
        "case_owner" => "me",
        "sort_by" => params["sort_by"],
        "sort_dir" => params["sort_dir"],
        "state" => "submitted",
        "page_name" => "your_cases"
      }
    )
    @submitted_pagy, @submitted_answer = search_for_investigations(page_param: :submitted_page)
    @submitted_count = @submitted_pagy.count
    @submitted_notifications = InvestigationDecorator
                                 .decorate_collection(@submitted_answer.includes({ owner_user: :organisation, owner_team: :organisation }, :products))
    @search = SearchParams.new(
      {
        "case_owner" => "me",
        "sort_by" => params["sort_by"],
        "sort_dir" => params["sort_dir"],
        "state" => "draft",
        "page_name" => "your_cases"
      }
    )
    @draft_pagy, @draft_answer = search_for_investigations(page_param: :draft_page)
    @draft_count = @draft_pagy.count
    @draft_notifications = InvestigationDecorator
                             .decorate_collection(@draft_answer.includes({ owner_user: :organisation, owner_team: :organisation }, :products))
  end

  # GET /notifications/team-notifications
  def team_notifications
    return redirect_to team_cases_investigations_path unless current_user.can_use_notification_task_list?

    @page_name = "team_cases"
    @search = SearchParams.new(
      {
        "case_owner" => "my_team",
        "sort_by" => params["sort_by"],
        "sort_dir" => params["sort_dir"],
        "state" => "submitted",
        "page_name" => "team_cases"
      }
    )
    @pagy, @answer = search_for_investigations
    @count = @pagy.count
    @investigations = InvestigationDecorator
                        .decorate_collection(@answer.includes({ owner_user: :organisation, owner_team: :organisation }, :products))

    render "notifications/index"
  end

  # GET /notifications/assigned-notifications
  def assigned_notifications
    return redirect_to assigned_cases_investigations_path unless current_user.can_use_notification_task_list?

    @page_name = "assigned_cases"
    @search = SearchParams.new(
      {
        "case_owner" => "all",
        "teams_with_access" => "my_team",
        "created_by" => "others",
        "sort_by" => params["sort_by"],
        "sort_dir" => params["sort_dir"],
        "state" => "submitted",
        "page_name" => "assigned_cases"
      }
    )
    @pagy, @answer = search_for_investigations
    @count = @pagy.count
    @investigations = InvestigationDecorator
                        .decorate_collection(@answer.includes({ owner_user: :organisation, owner_team: :organisation }, :products))

    render "notifications/index"
  end

  # GET /notifications/:pretty_id
  def show
    return redirect_to investigation_path(@notification) unless current_user.can_use_notification_task_list?

    breadcrumb breadcrumb_case_label, breadcrumb_case_path

    # Find the most recent incomplete bulk products upload for the current user and case, if any
    @incomplete_bulk_products_upload = BulkProductsUpload.where(user: current_user, submitted_at: nil, investigation: @notification).order(updated_at: :desc).first
  end

  # GET /notifications/:pretty_id/access
  def access; end

  # GET /notifications/:pretty_id/delete
  def delete; end

  # DELETE /notifications/:pretty_id/destroy
  def destroy
    if policy(@notification).delete?(user: current_user)
      @notification.destroy!
      flash[:success] = "The notification has been deleted."
    end

    redirect_to your_notifications_path
  end

private

  def set_last_case_view_cookie
    cookies[:last_case_view] = params[:action]
  end

  def count_to_display
    default_params ? Investigation.not_deleted.count : @pagy.count
  end

  def set_search_params
    @search = SearchParams.new(query_params.except(:page_name))
  end

  def default_params
    params["case_statuses"] == %w[open closed] && params[:q].blank?
  end

  def set_notification
    @notification = Investigation::Notification.includes(:creator_user, :creator_team, :owner_user, :owner_team, :comments).find_by!(pretty_id: params[:pretty_id])
  end
end
