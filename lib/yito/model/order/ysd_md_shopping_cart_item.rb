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

        property :custom_customers_pickup_place, Boolean, :default => false
        property :customers_pickup_place, String, :length => 256

        property :request_customer_information, Boolean, :default => false
        property :request_customer_address, Boolean, :default => false
        property :request_customer_document_id, Boolean, :default => false
        property :request_customer_phone, Boolean, :default => false
        property :request_customer_email, Boolean, :default => false
        property :request_customer_height, Boolean, :default => false
        property :request_customer_weight, Boolean, :default => false
        property :request_customer_allergies_intolerances, Boolean, :default => false
        property :uses_planning_resources, Boolean, :default => false

        belongs_to :shopping_cart, 'ShoppingCart', :child_key => [:shopping_cart_id]
        has n, :shopping_cart_item_customers, 'ShoppingCartItemCustomer', :constraint => :destroy
                  
        def item_activity
          ::Yito::Model::Booking::Activity.first(code: item_id) if item_id and !item_id.nil?
        end

      end
    end
  end
end