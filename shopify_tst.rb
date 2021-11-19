require 'shopify_api'

ActiveSupport::Deprecation.silenced = true

ShopifyAPI::Base.site = "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_PASSWORD']}@benton-dev.myshopify.com"

ShopifyAPI::Base.api_version = '2020-10'

class LifeTimeValue
    attr_reader :total_time, :total_spend, :total_clients
    
    
end

#idealy:
#vr class to check placed order (meaning some business definition)
#iterator using this vr class along with ltv and productiterator

#client_total class, used to keep the first and last time they buy, total spent

#ltv  class, should use the client_total, provide totalization afterwards

#productiterator should iterate products adding with
# a new product_total class, to sum quantity sold by product, value other
# possible business needs, as shipment, avg quantity by order

#dashboard using this iterator composer

class Dashboard
    attr_reader :total_placed_orders,:total_cancel,:total_confirmed

    def initialize()
        @orders = ShopifyAPI::Order.find(:all, params: { limit: 25 })
        #TODO should only return the fields being used
    end

    def countPlacedOrders
        @total_placed_orders = 0

        countOrders(@orders)

        while @orders.next_page?
            @orders = @orders.fetch_next_page
            countOrders(@orders)
        end

    end

    def countOrders(orders)
        for i in 0..(orders.length-1) do

            if orders[i].confirmed && !orders[i].test && orders[i].cancel_reason.to_s.length == 0
                @total_placed_orders += 1
            end

        end
    end
end

#cancel_reason
#confirmed
#test = false

#price related:
#subtotal_price
#total_discount
#total_price
#presentment_currency -> might have different currencies, check total price_usb make sense

#financial_status = paid?

#orders = ShopifyAPI::Order.find(:all, params: { limit: 250 })

#irb -r './shopify_tst.rb'
#dash = Dashboard.new
#dash.countPlacedOrders
#dash.total_placed_orders
