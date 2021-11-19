require 'shopify_api'

ActiveSupport::Deprecation.silenced = true

ShopifyAPI::Base.site = "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_PASSWORD']}@benton-dev.myshopify.com"

ShopifyAPI::Base.api_version = '2020-10'

class Dashboard
    #not the design I wanted, the dashboard should be a composer,
    #but it's taking too long to discover the best ways to use ruby classes
    
    #would have a lot of improvements to do for testing and clean code

    #idealy, any characteristic could be mapped to a validation rule class
    #after the first layer of characteristics, composer-like classes, could cross information
    #between,  eg. clients vs products, consuming the already updated interfaces...

    attr_reader :total_placed_orders,:total_cancel,:total_confirmed

    def initialize()
        @orders = ShopifyAPI::Order.find(:all, params: { limit: 25 })
        #TODO should only return the fields being used!
        #TODO save locally and set a timeout for next search or create an event to search again
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

        Product_totals.updateTimesOnFirstOrder(Client_totals.all_clients)

        reating = RepeatProducts.new(Product_totals.all_products)
        reating.calculate()
        reating.showAll()
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

            for p in 0..(orders[i].line_items.length-1) do

                Product_totals.new(orders[i].line_items[p], orders[i].customer.id)

            end
        end
    end

    def showTotals
        puts "total_confirmed:#{total_confirmed} \n total_placed_orders:#{total_placed_orders} \n total_cancel:#{total_cancel}"
    end

    def is_placed_order?(order)
        order.confirmed && !order.test && order.cancel_reason.to_s.length == 0
    end
    
    def is_canceled_order?(order)
        order.cancel_reason.to_s.length > 0
    end
    
    def is_confirmed_order?(order)
        order.confirmed
    end
end

class SimpleOrder
    attr_accessor :created_at,:products

    def initialize(order)
        @created_at = Time.iso8601(order.created_at).to_i
        @products = Array.new

        for p in 0..(order.line_items.length-1) do

            @products << order.line_items[p].product_id

        end
    end
end

class Client_totals
    @@allClients = Array.new

    attr_accessor :id, :first_order_at, :last_order_at, :total_spent, :total_time, :orders_count, :orders, :firstOrderProducts

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
        @firstOrderProducts = order.line_items
        @orders = [SimpleOrder.new(order)]

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
            @@allClients[foundIndex].orders << @orders[0]
        end
    end

    def updateDates(foundIndex)
        #puts ("First order at:").concat(@@allClients[foundIndex].first_order_at)
        if Time.iso8601(@first_order_at) < Time.iso8601(@@allClients[foundIndex].first_order_at)
            @@allClients[foundIndex].first_order_at = @first_order_at
            @@allClients[foundIndex].firstOrderProducts = @firstOrderProducts
            #puts "first order changed"
        end

        if Time.iso8601(@last_order_at) > Time.iso8601(@@allClients[foundIndex].last_order_at)
            @@allClients[foundIndex].last_order_at = @last_order_at
            #puts "last order changed"
        end
        #puts "-----"
    end

    def updateTotalTime(foundIndex)
        @@allClients[foundIndex].total_time = Time.iso8601(@@allClients[foundIndex].last_order_at).to_i - Time.iso8601(@@allClients[foundIndex].first_order_at).to_i
    end
end

class LifeTimeValue
    attr_reader :ltv, :clv, :profit_margin, :total_time, :total_spent, :total_clients, :total_orders, :total_repeatable_orders, :total_repeatable_spent, :avg_spent_by_client, :avg_spent_by_order, :avg_time, :avg_time_between_orders
    @allClients = Array.new
    
    def initialize(allClients)
        @allClients = allClients
        @total_clients = @allClients.length()
        @total_time = 0
        @total_spent = 0
        @total_orders = 0
        @total_repeatable_orders = 0
        @total_repeatable_spent = 0
        @avg_spent_by_client = 0
        @avg_spent_by_order = 0
        @avg_time = 0 #output on secs
        @avg_time_between_orders = 0
        @ltv = 0
        @clv = 0
        @profit_margin = 1.8

        puts "total_clients: #{total_clients}"
    end

    def calculate()
        for client in @allClients do
            @total_time = @total_time + client.total_time
            @total_spent = @total_spent + client.total_spent
            @total_orders = @total_orders + client.orders_count

            if client.orders_count > 1
                @total_repeatable_orders = @total_repeatable_orders + client.orders_count
                @total_repeatable_spent = @total_repeatable_spent + client.total_spent
            end
        end

        @avg_spent_by_client = @total_spent / @total_clients
        @avg_spent_by_order = @total_spent / @total_orders
        @avg_time = @total_time / @total_repeatable_orders

        @ltv = @avg_spent_by_order * @total_repeatable_orders * @avg_time
        @clv = @ltv * @profit_margin
    end

    def showAll()
        print "\ntotal_time: #{total_time}
total_spent: #{total_spent}
total_clients: #{total_clients}
total_orders: #{total_orders} 
total_repeatable_orders: #{total_repeatable_orders} 
avg_spent_by_client (USD): #{avg_spent_by_client}
avg_spent_by_order (USD): #{avg_spent_by_order} 
avg_time_between_orders (s): #{avg_time}
LTV: #{ltv}
CLV (profit margin: #{profit_margin}): #{clv} \n"
    end
end

class Product_totals
    @@allProducts = Array.new

    attr_accessor :id, :name, :buyers, :ordersTime, :total_orders, :replanInterval, :avgReplanInt, :total_sold, :total_value, :unique_buyers, :times_on_first_order, :times_bought, :avg_price

    def self.all_products
        @@allProducts
    end

    def self.updateTimesOnFirstOrder(allClients)
        for client in allClients do
            for p in 0..(client.firstOrderProducts.length-1) do
                foundIndex = @@allProducts.index { |product| product.id == client.firstOrderProducts[p].product_id }
                if foundIndex != nil
                    @@allProducts[foundIndex].times_on_first_order = @@allProducts[foundIndex].times_on_first_order + 1
                end
            end
        end

        for p in 0..(@@allProducts.length-1) do
            for client in allClients do
                sortedOrders = client.orders.sort {|a,b| a.created_at <=> b.created_at}
                buyTimes = []

                for o in 0..(sortedOrders.length-1) do
                    foundIndex = sortedOrders[o].products.index { |product| product == @@allProducts[p].id }
                    if foundIndex != nil
                        buyTimes << sortedOrders[o].created_at
                    end
                end

                if buyTimes.length > 0
                    @@allProducts[p].ordersTime << buyTimes
                end
            end

            @@allProducts[p].replanInterval = []
            @@allProducts[p].total_orders = 0
            for t in 0..(@@allProducts[p].ordersTime.length-1) do
                @@allProducts[p].total_orders = @@allProducts[p].total_orders + @@allProducts[p].ordersTime[t].length
                if @@allProducts[p].ordersTime[t].length > 1

                    for tt in 0..(@@allProducts[p].ordersTime[t].length-2) do
                        @@allProducts[p].replanInterval << @@allProducts[p].ordersTime[t][(tt+1)] - @@allProducts[p].ordersTime[t][tt]
                    end
                end
            end
        end
    end

    def self.calculateSelfAverages()
        for p in 0..(@@allProducts.length-1) do
            @@allProducts[p].avg_price = @@allProducts[p].total_value / @@allProducts[p].total_sold
            
            @@allProducts[p].avgReplanInt = 0
            if @@allProducts[p].replanInterval.length > 0
                totalReplanInt = 0
                for r in 0..(@@allProducts[p].replanInterval.length-1) do
                    totalReplanInt = totalReplanInt + @@allProducts[p].replanInterval[r]
                end
                @@allProducts[p].avgReplanInt = totalReplanInt / @@allProducts[p].replanInterval.length
            end
        end
    end

    def initialize(lineItem, clientId)
        @id = lineItem.product_id
        @name = lineItem.name
        @total_sold = lineItem.quantity
        @total_value = lineItem.price.to_f * lineItem.quantity.to_i
        @avg_price = 0
        @unique_buyers = 1
        @buyers = [clientId]
        @ordersTime = []
        @replanInterval = []
        @times_on_first_order = 0
        @avgReplanInt = 0
        @times_bought = 1
        @total_orders = 0

        #by clean code, no logic should be here. Iam sorry =/
        addOrChange()
    end

    def addOrChange()
        foundIndex = @@allProducts.index { |product| product.id == @id }
        if foundIndex == nil
            @@allProducts << self
            updateTotals(@@allProducts.length() - 1)
            #puts "#{id} added"
        else
            #puts "#{foundIndex} found"
            updateTotals(foundIndex)
            updateUniqueBuyers(foundIndex)
        end
    end

    def updateTotals(foundIndex)
        @@allProducts[foundIndex].total_sold = @@allProducts[foundIndex].total_sold + @total_sold
        @@allProducts[foundIndex].total_value = @@allProducts[foundIndex].total_value + @total_value
        @@allProducts[foundIndex].times_bought = @@allProducts[foundIndex].times_bought + 1
    end

    def updateUniqueBuyers(foundIndex)
        foundBuyer = @@allProducts[foundIndex].buyers.index { |buyerid| buyerid == @buyers[0] }
        if foundBuyer == nil
            @@allProducts[foundIndex].buyers << @buyers[0]
            #puts "#{buyers[0]} buyerId added"
        end
    end
end

class RepeatProducts
    attr_reader :total_revenue, :total_products
    @allProducts = Array.new
    @total_products = 0
    @total_revenue = 0
    
    def initialize(allProducts)
        @allProducts = allProducts
        @total_products = @allProducts.length()
        @total_revenue = 0

        puts "total_products: #{total_products}"
    end

    def calculate()
        for product in @allProducts do
            @total_revenue = @total_revenue + product.total_value
        end

        Product_totals.calculateSelfAverages()
    end

    def showAll()
        showMostRevenue()
        showAvgPriceQuantity()
        showReplanishmentInterval()
    end

    def showMostRevenue()
        sorted = @allProducts.sort {|a,b| b.total_value <=> a.total_value}
        puts "\nMost Revenue by order:"
        puts "%23s | %13s | %9s" % ["Product", "Total Revenue", "Revenue %"]
        for i in 0..(sorted.length-1) do
            revenuePercentage = sorted[i].total_value / @total_revenue * 100

            puts "%23s | %3.2f USD | %2.2f" % [sorted[i].name, sorted[i].total_value, revenuePercentage]
        end
        puts "\n"
    end

    def showAvgPriceQuantity()
        sorted = @allProducts.sort {|a,b| b.avg_price <=> a.avg_price}
        puts "\nAvgs price, quantity, chance to be on first order:"
        puts "%23s | %9s | %6s | %s | %s | %s | %s | %s" % ["Product", "Avg Price", "AvgQnt", "Total Sold", "Times bought", "Chance to be 1st order", "Unique buyers", "Avg Replanishment Interval (s)"]
        for i in 0..(sorted.length-1) do
            avg_quantity_in_order = sorted[i].total_sold / sorted[i].times_bought
            chance = sorted[i].times_on_first_order / sorted[i].buyers.length().to_f * 100
            puts "%23s | %3.2f USD | %2.2f | %d | %d | %2.2f | %d | %0.2f" % [sorted[i].name, sorted[i].avg_price, avg_quantity_in_order, sorted[i].total_sold, sorted[i].times_bought, chance, sorted[i].buyers.length(), sorted[i].avgReplanInt]
        end
        puts "\n"
    end

    def showReplanishmentInterval()
        sorted = @allProducts.sort_by do |product|
            [(product.avgReplanInt == 0 ? 1 : 0), -product.total_orders, -product.avgReplanInt]
        end
        
        puts "\nReplanishment Intervals, 0 = insufficient data:"
        puts "%23s | %s | %s | %s" % ["Product", "# Orders", "Unique buyers", "Avg Replanishment Interval (s)"]
        for i in 0..(sorted.length-1) do
            puts "%23s | %d | %d | %d " % [sorted[i].name, sorted[i].total_orders, sorted[i].buyers.length(), sorted[i].avgReplanInt ]
        end
        puts "\n"
    end
end

#to test:
#irb -r './shopify_tst.rb'
#dash = Dashboard.new
