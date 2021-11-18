# frozen_string_literal: true

#
# Proxy files through application. This avoids having a redirect and makes files easier to cache.
# Overrides Rails Controller to enforce access protection beyond the security-through-obscurity
# factor of the signed blob and variation reference.
# Only owners and search users have access to files.

class ActiveStorage::Blobs::ProxyController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob
  include ActiveStorage::SetHeaders
  include ActiveStorage::SetCurrent
  include HttpAuthConcern
  include SentryConfigurationConcern
  include Pundit

  self.etag_with_template_digest = false

  before_action :authorize_blob

  def show
    set_content_headers_from @blob
    stream @blob
  end

private

  def authorize_blob
    return redirect_to "/sign-in" unless user_signed_in?

    return redirect_to "/", flash: { warning: "Not authorized to view this attachment" } if investigation && !InvestigationPolicy.new(current_user, investigation).view_protected_details?

    investigation = product.investigations.first if product

    return redirect_to "/", flash: { warning: "Not authorized to view this attachment" } if investigation && !InvestigationPolicy.new(current_user, investigation).view_protected_details?
  end

  def investigation
    investigation_id = @blob.attachments.find_by(record_type: "Investigation").try(:record_id)
    investigation = Investigation.find(investigation_id) if investigation_id
  end

  def product
    product_id = @blob.attachments.find_by(record_type: "Product").try(:record_id)
    product = Product.find(product_id) if product_id
  end
end
