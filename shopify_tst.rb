require 'shopify_api'

ActiveSupport::Deprecation.silenced = true

ShopifyAPI::Base.site = "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_PASSWORD']}@benton-dev.myshopify.com"

ShopifyAPI::Base.api_version = '2020-10'

class LifeTimeValue
    attr_reader :total_time, :total_spend, :total_clients
    
    
end

#interfaces use raise NotImplementedError, "Implement this method in a child class"
#or new gems
# deciding to not use here

#idealy:
#vr class to check placed order (meaning some business definition)
#iterator using this vr class along with ltv and productiterator

#client_total class, used to keep the first and last time they buy, total spent

#ltv  class, should use the client_total, provide totalization afterwards

#productiterator should iterate products adding with
# a new product_total class, to sum quantity sold by product, value other
# possible business needs, as shipment, avg quantity by order

#dashboard using this iterator composer

def is_placed_order?(order)
    order.confirmed && !order.test && order.cancel_reason.to_s.length == 0
end

def is_canceled_order?(order)
    order.cancel_reason.to_s.length > 0
end

def is_confirmed_order?(order)
    order.confirmed
end

class Client_totals
    @@allClients = Array.new
    attr_accessor :id, :first_order_at, :last_order_at, :total_spent

    def self.all_instances
        @@allClients
    end

    def initialize(order)
        @id = order.customer.id
        @first_order_at = order.created_at
        @last_order_at = order.created_at
        @total_spent = order.customer.total_spent

        addOrChange()
    end

    def addOrChange()
        foundIndex = @@allClients.index { |client| client.id == @id }
        if foundIndex == nil
            @@allClients << self
            #puts "#{id} added"
        else
            #puts "#{foundIndex} found"
            updateDates(foundIndex)
        end
    end

    def updateDates(foundIndex)
        #puts ("First order at:").concat(@@allClients[foundIndex].first_order_at)
        if Time.iso8601(@first_order_at) < Time.iso8601(@@allClients[foundIndex].first_order_at)
            @@allClients[foundIndex].first_order_at = @first_order_at
            #puts "first order changed"
        end

        if Time.iso8601(@last_order_at) > Time.iso8601(@@allClients[foundIndex].last_order_at)
            @@allClients[foundIndex].last_order_at = @last_order_at
            #puts "last order changed"
        end
        #puts "-----"
    end
end

class Dashboard
    attr_reader :total_placed_orders,:total_cancel,:total_confirmed

    def initialize()
        @orders = ShopifyAPI::Order.find(:all, params: { limit: 25 })
        #TODO should only return the fields being used1
    end

    def countPlacedOrders
        @total_placed_orders = 0
        @total_cancel = 0
        @total_confirmed = 0

        countOrders(@orders)

        while @orders.next_page?
            @orders = @orders.fetch_next_page
            countOrders(@orders)
        end
    end

    def countOrders(orders)
        for i in 0..(orders.length-1) do

            if is_placed_order?(orders[i])
                @total_placed_orders += 1
            end

            if is_canceled_order?(orders[i])
                @total_cancel += 1
            end

            if is_confirmed_order?(orders[i])
                @total_confirmed += 1
            end

            Client_totals.new(orders[i])

        end
    end

    def showTotals
        puts "total_confirmed:#{total_confirmed} \n total_placed_orders:#{total_placed_orders} \n total_cancel:#{total_cancel}"
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
