module Notifications
  class AddSupportingImagesController < ApplicationController
    include BreadcrumbHelper

    before_action :set_notification
    before_action :validate_step
    before_action :set_image_upload, only: [:show]
    before_action :set_remove_image_upload, only: [:remove_upload]

    breadcrumb "notifications.label", :your_notifications

    def show
      @image_upload = ImageUpload.new(upload_model: @notification)
      render :add_supporting_images
    end

    def update
      flash[:success] = nil
      @image_upload = ImageUpload.new(upload_model: @notification)

      if image_upload_params[:file_upload].present?
        handle_file_upload
      else
        handle_redirect
      end
    end

    def remove_upload
      if request.delete?
        handle_image_removal
      else
        render :remove_upload
      end
    end

  private

    def handle_image_removal
      if @image_upload.upload_model != @notification
        head :forbidden
      else
        remove_image
        flash[:success] = "Supporting image removed successfully"
        redirect_to notification_add_supporting_images_path(@notification)
      end
    end

    def remove_image
      ActiveRecord::Base.transaction do
        @notification.image_upload_ids.delete(@image_upload.id)
        @notification.save!
        @image_upload.destroy!
      end
    end

    def handle_file_upload
      create_and_attach_file
    rescue ActiveStorage::IntegrityError
      @image_upload.errors.add(:file_upload, "must be a GIF, JPEG, PNG, WEBP or HEIC/HEIF file")
      flash[:error] = @image_upload.errors.full_messages.to_sentence
      render :add_supporting_images
    end

    def create_and_attach_file
      file = create_blob
      @image_upload = create_image_upload(file)

      if @image_upload.valid?
        save_image_upload
        handle_redirect
      else
        file.purge
        flash[:error] = @image_upload.errors.full_messages.to_sentence
        render :add_supporting_images
      end
    end

    def create_blob
      file = ActiveStorage::Blob.create_and_upload!(
        io: image_upload_params[:file_upload],
        filename: image_upload_params[:file_upload].original_filename,
        content_type: image_upload_params[:file_upload].content_type
      )
      file.analyze_later
      file
    end

    def create_image_upload(file)
      ImageUpload.new(
        file_upload: file,
        upload_model: @notification,
        created_by: current_user.id
      )
    end

    def save_image_upload
      @image_upload.save!
      @notification.image_upload_ids.push(@image_upload.id)
      @notification.save!
      flash[:success] = "Supporting image uploaded successfully"
    end

    def handle_redirect
      if params[:final] == "true"
        redirect_to notification_path(@notification)
      else
        redirect_to notification_add_supporting_images_path(@notification)
      end
    end

    def validate_step
      return redirect_to "/404" unless @notification && current_user

      render "errors/forbidden", status: :forbidden unless user_can_edit?
    end

    def user_can_edit?
      user_team = current_user.team
      return false if @notification.teams_with_read_only_access.include?(user_team)

      [@notification.creator_user, @notification.owner_user].include?(current_user) ||
        [@notification.owner_team, @notification.creator_team].include?(user_team) ||
        @notification.teams_with_edit_access.include?(user_team)
    end

    def set_notification
      @notification = Investigation.find_by!(pretty_id: params[:notification_pretty_id])
    end

    def set_image_upload
      @image_upload = ImageUpload.new
    end

    def set_remove_image_upload
      @image_upload = ImageUpload.find(params[:upload_id])
    end

    def image_upload_params
      params.require(:image_upload).permit(:file_upload)
    end
  end
end
