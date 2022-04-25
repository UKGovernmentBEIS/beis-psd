class DocumentsController < ApplicationController
  include DocumentsHelper

  def new
    @parent = get_parent
    authorize_if_attached_to_investigation

    @document_form = DocumentForm.new

    @parent = @parent.decorate
  end

  def create
    @parent = get_parent
    authorize_if_attached_to_investigation

    @document_form = DocumentForm.new(document_params)
    @document_form.cache_file!(current_user)

    # sleep here to give analyze a chance to run before validating
    sleep 2

    unless @document_form.valid?
      @parent = @parent.decorate
      return render :new
    end

    AddDocument.call!(@document_form.attributes.except("existing_document_file_id").merge({
      parent: @parent,
      user: current_user,
    }))

    Rails.logger.info("Adddocumenthasbeencalledisthiswhenactivejobisrun?!?!")

    flash[:success] = t(:file_added, type: @parent.model_name.human.downcase)

    return redirect_to(@parent) unless @parent.is_a?(Investigation)
    return redirect_to investigation_images_path(@parent) if @document_form.document.image?

    redirect_to investigation_supporting_information_index_path(@parent)
  end

  # GET /documents/1/edit
  def edit
    @parent = get_parent
    authorize_if_attached_to_investigation

    @file = @parent.documents.find(params[:id])

    @document_form = DocumentForm.from(@file)

    @parent = @parent.decorate
  end

  # PATCH/PUT /documents/1
  def update
    @parent = get_parent
    authorize_if_attached_to_investigation

    @file = @parent.documents.find(params[:id])

    @document_form = DocumentForm.from(@file)
    @document_form.assign_attributes(document_params)

    unless @document_form.valid?
      @parent = @parent.decorate
      return render :edit
    end

    UpdateDocument.call!(@document_form.attributes.slice("title", "description").merge({
      parent: @parent,
      file: @file.blob,
      user: current_user,
    }))

    flash[:success] = t(:file_updated)

    return redirect_to(@parent) unless @parent.is_a?(Investigation)
    return redirect_to investigation_images_path(@parent) if @document_form.document.image?

    redirect_to investigation_supporting_information_index_path(@parent)
  end

  def remove
    @parent = get_parent
    authorize_if_attached_to_investigation

    @file = @parent.documents.find(params[:id])
  end

  # DELETE /documents/1
  def destroy
    @parent = get_parent
    authorize_if_attached_to_investigation

    @file = @parent.documents.find(params[:id])

    DeleteDocument.call!(
      document: @file,
      parent: @parent,
      user: current_user
    )

    flash[:success] = t(:file_removed)

    return redirect_to(@parent) unless @parent.is_a?(Investigation)
    return redirect_to investigation_images_path(@parent) if @file.image?

    redirect_to investigation_supporting_information_index_path(@parent)
  end

private

  def document_params
    params.require(:document).permit(:existing_document_file_id, :document, :title, :description)
  end

  def get_parent
    if (pretty_id = params[:investigation_pretty_id] || params[:allegation_id] || params[:project_id] || params[:enquiry_id])
      return Investigation.find_by!(pretty_id:)
    end

    return Product.find(params[:product_id]) if params[:product_id]
    return Business.find(params[:business_id]) if params[:business_id]
  end

  def authorize_if_attached_to_investigation
    authorize @parent, :update? if @parent.is_a? Investigation
  end
end
