require 'shopify_api'

ActiveSupport::Deprecation.silenced = true

ShopifyAPI::Base.site = "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_PASSWORD']}@benton-dev.myshopify.com"

ShopifyAPI::Base.api_version = '2020-10'

class LifeTimeValue
    attr_reader :total_time, :total_spent, :total_clients, :total_orders, :total_repeatable_orders, :avg_spent_by_client, :avg_spent_by_order, :avg_time, :avg_time_between_orders, :avg_orders_count_by_time
    @allClients = Array.new
    
    def initialize(allClients)
        @allClients = allClients
        @total_clients = @allClients.length()
        @total_time = 0
        @total_spent = 0
        @total_orders = 0
        @total_repeatable_orders = 0
        @avg_spent_by_client = 0
        @avg_spent_by_order = 0
        @avg_time = 0
        @avg_time_between_orders = 0
        @avg_orders_count_by_time = 0

        puts "total_clients: #{total_clients}"
    end

    def calculate()
        for client in @allClients do
            @total_time = @total_time + client.total_time
            @total_spent = @total_spent + client.total_spent
            @total_orders = @total_orders + client.orders_count

            if client.orders_count > 1
                @total_repeatable_orders = @total_repeatable_orders + client.orders_count
            end
        end

        @avg_spent_by_client = @total_spent / @total_clients
        @avg_spent_by_order = @total_spent / @total_orders
        @avg_time = @total_time / @total_repeatable_orders
    end

    def showAll()
        puts "total_time: #{total_time}
total_spent: #{total_spent}
total_clients: #{total_clients}
total_orders: #{total_orders} 
avg_spent_by_client: #{avg_spent_by_client}
avg_spent_by_order: #{avg_spent_by_order} 
avg_time: #{avg_time}
avg_orders_count_by_time: #{avg_orders_count_by_time}"
    end    
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

    attr_accessor :id, :first_order_at, :last_order_at, :total_spent, :total_time, :orders_count

    def self.all_clients
        @@allClients
    end

    def initialize(order)
        @id = order.customer.id
        @orders_count = order.customer.orders_count.to_i
        @first_order_at = order.created_at
        @last_order_at = order.created_at
        @total_spent = order.customer.total_spent.to_i
        @total_time = 0

        #by clean code, no logic should be here. Iam sorry =/
        addOrChange()
    end

    def addOrChange()
        foundIndex = @@allClients.index { |client| client.id == @id }
        if foundIndex == nil
            @@allClients << self
            updateTotalTime(@@allClients.length() - 1)
            #puts "#{id} added"
        else
            #puts "#{foundIndex} found"
            updateDates(foundIndex)
            updateTotalTime(foundIndex)
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

    def updateTotalTime(foundIndex)
        @@allClients[foundIndex].total_time = Time.iso8601(@@allClients[foundIndex].last_order_at) - Time.iso8601(@@allClients[foundIndex].first_order_at)
    end
end

class Dashboard
    attr_reader :total_placed_orders,:total_cancel,:total_confirmed

    def initialize()
        @orders = ShopifyAPI::Order.find(:all, params: { limit: 25 })
        #TODO should only return the fields being used1
        countPlacedOrders()
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

        ltv = LifeTimeValue.new(Client_totals.all_clients)
        ltv.calculate()
        ltv.showAll()
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
