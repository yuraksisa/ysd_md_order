module Yito
  module Model
  	module Order
  	  class OrderItem
  	  	include DataMapper::Resource

        storage_names[:default] = 'orderds_order_items' 
  	  	
        property :id, Serial

        property :date, DateTime, :field => 'date', :required => false
        property :time, String, :field => 'time', :required => false, :length => 5

        property :item_id, String, :length => 20, :required => true
        property :item_description, String, :length => 256        
        property :item_unit_cost, Decimal, :precision => 10, :scale => 2
        property :quantity, Integer
        property :item_cost, Decimal, :precision => 10, :scale => 2
        property :item_price_type, Integer, :required => true, :default => 1

        property :comments, Text
        property :notes, Text

        belongs_to :order, 'Order', :child_key => [:order_id]
   
        property :status, Enum[:pending_confirmation, :confirmed,  
           :cancelled], :field => 'status', :default => :pending_confirmation
        
      end
    end
  end
end