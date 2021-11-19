require 'shopify_api'

ActiveSupport::Deprecation.silenced = true

ShopifyAPI::Base.site = "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_PASSWORD']}@benton-dev.myshopify.com"

ShopifyAPI::Base.api_version = '2020-10'

#confirmed
#test = false

#price related:
#subtotal_price
#total_discount
#total_price
#presentment_currency -> might have different currencies, check total price_usb make sense

ShopifyAPI::Order.find(:all).first