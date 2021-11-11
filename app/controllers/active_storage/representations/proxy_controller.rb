# frozen_string_literal: true

# Overrides original Rails implementation to disable route:
# /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)
# We use "rails storage proxy" through ActiveStorage::Blobs::ProxyController
class ActiveStorage::Representations::ProxyController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob
  include ActiveStorage::SetHeaders
  include Pundit

  before_action :authorize_blob

  def show
    http_cache_forever public: true do
      set_content_headers_from representation.image
      stream representation
    end
  end

  private

  def pundit_user
    current_user
  end

  def authorize_blob
    redirect_to new_user_session_path unless user_signed_in?
  end

  def representation
    @representation ||= @blob.representation(params[:variation_key]).processed
  end
end
