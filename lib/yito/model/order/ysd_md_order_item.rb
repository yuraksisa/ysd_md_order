module Yito
  module Model
  	module Order
  	  class OrderItem
  	  	include DataMapper::Resource

        storage_names[:default] = 'orderds_order_items' 
  	  	
        property :id, Serial

        property :date, DateTime, :field => 'date', :required => false
        property :time, String, :field => 'time', :required => false, :length => 5
        property :date_to, DateTime, :field => 'date_to', :required => false
        property :time_to, String, :field => 'time_to', :required => false

        property :item_id, String, :length => 20, :required => true
        property :item_description, String, :length => 256
        property :item_description_customer_translation, String, :length => 256
        property :item_unit_cost, Decimal, :precision => 10, :scale => 2
        property :quantity, Integer
        property :item_cost, Decimal, :precision => 10, :scale => 2
        property :item_price_type, Integer, :required => true, :default => 1
        property :item_price_description, String, :length => 256
        
        property :comments, Text
        property :notes, Text

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

        property :item_payment_setup, Enum[:default, :custom], default: :default
        property :item_custom_payment_allow_deposit_payment, Boolean, default: false
        property :item_custom_payment_deposit, Integer, default: 0
        property :item_custom_payment_allow_total_payment, Boolean, default: false

        belongs_to :order, 'Order', :child_key => [:order_id]
        
        has n, :order_item_customers, 'OrderItemCustomer', :constraint => :destroy
        has n, :order_item_resources, 'OrderItemResource', :constraint => :destroy

        alias_method :customers, :order_item_customers
        alias_method :resources, :order_item_resources
   
        property :status, Enum[:pending_confirmation, :confirmed,  
           :cancelled], :field => 'status', :default => :pending_confirmation

        def item_activity
              ::Yito::Model::Booking::Activity.first(code: item_id) if item_id and !item_id.nil?
        end

      end
    end
  end
end