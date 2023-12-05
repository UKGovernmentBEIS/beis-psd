module ProductsHelper
  def search_for_products(page_size = Product.count, user = current_user, for_export: false)
    query = Product.includes(child_records(for_export))

    if @search.q.present?
      @search.q.strip!
      query = query.where("products.name ILIKE ?", "%#{@search.q}%")
        .or(Product.where("products.description ILIKE ?", "%#{@search.q}%"))
        .or(Product.where("CONCAT('psd-', products.id) = LOWER(?)", @search.q))
        .or(Product.where(id: @search.q))
    end

    query = query.where(category: @search.category) if @search.category.present?

    query = query.where(investigations: { is_closed: false }) if @search.case_status == "open_only"

    query = query.where(retired_at: nil) if @search.retired_status == "active" || @search.retired_status.blank?

    query = query.where.not(retired_at: nil) if @search.retired_status == "retired"

    case @search.case_owner
    when "me"
      query = query.where(users: { id: user.id })
    when "my_team"
      team = user.team
      query = query.where(users: { id: team.users.map(&:id) }, teams: { id: team.id })
    end

    return query if for_export

    query
      .order(sorting_params)
      .page(page_number)
      .per(page_size)
  end

  def product_export_params
    params.permit(:q, :category)
  end

  def child_records(for_export)
    return [:investigations, :owning_team, { investigation_products: [:test_results, { corrective_actions: [:business], risk_assessments: %i[assessed_by_business assessed_by_team] }] }] if for_export

    { investigations: %i[owner_user owner_team] }
  end

  def sorting_params
    return {} if params[:sort_by] == SortByHelper::SORT_BY_RELEVANT
    return { name: :desc } if params[:sort_by] == SortByHelper::SORT_BY_NAME && params[:sort_dir] == SortByHelper::SORT_DIRECTION_DESC
    return { name: :asc } if params[:sort_by] == SortByHelper::SORT_BY_NAME

    { created_at: :desc }
  end

  def sort_direction
    SortByHelper::SORT_DIRECTIONS.include?(params[:sort_dir]) ? params[:sort_dir] : :desc
  end

  def page_number
    params[:page].to_i > 500 ? "500" : params[:page]
  end

  def set_product
    @product = Product.find(params[:id]).decorate
  end

  def conditionally_disabled_items_for_authenticity(product_form, disable_all_items: false)
    items = items_for_authenticity product_form
    return items unless disable_all_items

    items.map { |item| item.merge(disabled: true) }
  end

  def items_for_authenticity(product_form)
    items = [
      { text: "Yes", value: "counterfeit" },
      { text: "No", value: "genuine" }
    ]

    return items if product_form.authenticity.blank?

    set_selected_authenticity_option(items, product_form)
  end

  def items_for_before_2021_radio(product_form)
    items = [
      { text: "Yes", value: "before_2021" },
      { text: "No", value: "on_or_after_2021" },
      { text: "Unable to ascertain", value: "unknown_date" }
    ]
    return items if product_form.when_placed_on_market.blank?

    set_selected_when_placed_on_market_option(items, product_form)
  end

  def options_for_country_of_origin(countries, product_form)
    options = [{ text: "Unknown", value: "Unknown" }]
    options << countries.map do |country|
      text = country[0]
      option = { text:, value: country[1] }
      option[:selected] = true if product_form.country_of_origin == text
      option
    end
    options.flatten
  end

private

  def set_selected_authenticity_option(items, product_form)
    items.each do |item|
      next if skip_selected_item_for_selected_option?(item, product_form)

      item[:selected] = true if authenticity_selected?(item, product_form)
    end
  end

  def set_selected_when_placed_on_market_option(items, product_form)
    items.each do |item|
      next if skip_selected_item_for_selected_option?(item, product_form)

      item[:selected] = true if when_placed_on_market_option_selected?(item, product_form)
    end
  end

  def authenticity_selected?(item, product_form)
    item[:value] == product_form.authenticity
  end

  def when_placed_on_market_option_selected?(item, product_form)
    item[:value] == product_form.when_placed_on_market
  end

  def skip_selected_item_for_selected_option?(item, product_form)
    item[:divider] || item[:value].inquiry.missing? && product_form.id.nil?
  end
end
