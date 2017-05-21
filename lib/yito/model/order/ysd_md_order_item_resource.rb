module Yito
  module Model
  	module Order
  	  #
  	  # It represents a resource attached to an order. 
  	  # It can be used in the planning
  	  #	
  	  class OrderItemResource
  	  	include DataMapper::Resource

        storage_names[:default] = 'orderds_order_item_resources' 

        property :id, Serial

        property :booking_item_category, String, :length => 20
        property :booking_item_reference, String, :length => 50
        property :booking_item_stock_model, String, :length => 80
        property :booking_item_stock_plate, String, :length => 80
        property :booking_item_characteristic_1, String, :length => 80
        property :booking_item_characteristic_2, String, :length => 80
        property :booking_item_characteristic_3, String, :length => 80
        property :booking_item_characteristic_4, String, :length => 80

        belongs_to :order_item, 'OrderItem', :child_key => [:order_item_id]

      end
    end
  end
end  