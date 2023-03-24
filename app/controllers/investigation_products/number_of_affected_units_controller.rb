module InvestigationProducts
  class NumberOfAffectedUnitsController < ApplicationController
    def edit
      @investigation_product = InvestigationProduct.find(params[:investigation_product_id])
      authorize @investigation_product.investigation, :update?
      @number_of_affected_units_form = NumberOfAffectedUnitsForm.from(@investigation_product)
    end

    def update
      @investigation_product = InvestigationProduct.find(params[:investigation_product_id])
      authorize @investigation_product.investigation, :update?

      @number_of_affected_units_form = NumberOfAffectedUnitsForm.new(number_of_affected_units_params)
      return render(:edit) if @number_of_affected_units_form.invalid?

      result = ChangeNumberOfAffectedUnits.call!(number_of_affected_units: @number_of_affected_units_form.number_of_affected_units,
                                                 affected_units_status: @number_of_affected_units_form.affected_units_status,
                                                 investigation_product: @investigation_product,
                                                 user: current_user)

      redirect_to investigation_path(@investigation_product.investigation), flash: result.changed ? { success: "The case information was updated" } : nil
    end

  private

    def number_of_affected_units_params
      params.require(:number_of_affected_units_form).permit(:affected_units_status, :exact_units, :approx_units)
    end
  end
end
