module Yito
  module Model
  	module Order
  	  class ShoppingCartItem
  	  	include DataMapper::Resource

        storage_names[:default] = 'orderds_shopping_cart_items' 
  	  	
        property :id, Serial

        property :date, DateTime, :field => 'date', :required => false
        property :time, String, :field => 'time', :required => false, :length => 5

        property :item_id, String, :length => 20, :required => true
        property :item_description, String, :length => 256        
        property :item_unit_cost, Decimal, :precision => 10, :scale => 2
        property :quantity, Integer
        property :item_cost, Decimal, :precision => 10, :scale => 2
        property :item_price_description, String, :length => 256
        property :item_price_type, Integer, :required => true, :default => 1

        belongs_to :shopping_cart, 'ShoppingCart', :child_key => [:shopping_cart_id]
          
      end
    end
  end
end