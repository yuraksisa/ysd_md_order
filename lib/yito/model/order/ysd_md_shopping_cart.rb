require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Order
  	  class ShoppingCart
  	  	include DataMapper::Resource

        storage_names[:default] = 'orderds_shopping_carts' 
  	  	
        property :id, Serial
        
        property :creation_date, DateTime 
        property :created_by_manager, Boolean, :default => false
        property :source, String, :length => 50 
        property :total_cost, Decimal, :scale => 2, :precision => 10, :default => 0
        property :comments, Text

        property :customer_name, String, :length => 40
        property :customer_surname, String, :length => 40
        property :customer_email, String, :length => 40
        property :customer_phone, String, :length => 15 
        property :customer_mobile_phone, String, :length => 15
        property :customer_language, String, :length => 3

        has n, :shopping_cart_items, 'ShoppingCartItem', :constraint => :destroy
        
        def empty?
          shopping_cart_items.empty?
        end

        #
        # Get the shopping cart items group by date, time and item_id
        #
        def shopping_cart_items_group_by_date_time_item_id
          result = {}
          idx = 1
          last_shopping_cart_item = nil
          shopping_cart_items.each do |shopping_cart_item|
            if last_shopping_cart_item.nil? or 
               (last_shopping_cart_item.date != shopping_cart_item.date or
                last_shopping_cart_item.time != shopping_cart_item.time or 
                last_shopping_cart_item.item_id != shopping_cart_item.item_id)
              result.store(idx, {items: [shopping_cart_item], total: shopping_cart_item.item_cost})
              idx += 1
              last_shopping_cart_item = shopping_cart_item
            else
              the_data = result[idx-1]
              the_data[:items] << shopping_cart_item
              the_data[:total] += shopping_cart_item.item_cost
            end
          end
          result
        end
        
        #
        # Get the item count
        #
        def items_count
          shopping_cart_items_group_by_date_time_item_id.size
        end

        #
        # Adds an item to the shopping cart
        # 
        def add_item(date, time, item_id, item_description, item_price_type,
                     quantity, item_unit_cost, item_price_description)

          # Check if item exists
          shopping_cart_item = ::Yito::Model::Order::ShoppingCartItem.first(date: date,
                                 time: time, item_id: item_id, item_price_type: item_price_type)

          if shopping_cart_item
            inc_cost = (quantity * shopping_cart_item.item_unit_cost)
            shopping_cart_item.quantity += quantity
            shopping_cart_item.item_cost += inc_cost
            shopping_cart_item.save
            self.total_cost += inc_cost
          else
            shopping_cart_item = ::Yito::Model::Order::ShoppingCartItem.new
            shopping_cart_item.date = date
            shopping_cart_item.time = time
            shopping_cart_item.item_id = item_id
            shopping_cart_item.item_description = item_description
            shopping_cart_item.item_price_description = item_price_description
            shopping_cart_item.item_price_type = item_price_type
            shopping_cart_item.quantity = quantity
            shopping_cart_item.item_unit_cost = item_unit_cost
            shopping_cart_item.item_cost = shopping_cart_item.item_unit_cost * shopping_cart_item.quantity
            self.shopping_cart_items << shopping_cart_item
            self.total_cost += shopping_cart_item.item_cost
          end

        end
        
        #
        # Remove an item from the shopping cart
        #
        def remove_item(date,time,item_id)

          shopping_cart_items = ::Yito::Model::Order::ShoppingCartItem.all(shopping_cart_id: self.id,
                                                                           date: date,
                                                                           time: time,
                                                                           item_id: item_id)
          
          if shopping_cart_items.size > 0
            shopping_cart_items.each do |shopping_cart_item|
              shopping_cart_item.destroy
              self.total_cost -= shopping_cart_item.item_cost
            end
            self.save
          end

        end

      end
    end
  end
end