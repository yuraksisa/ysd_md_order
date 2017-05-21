module Yito
  module Model
  	module Order
  	  #
  	  # It represents customer information about the customer that will do the activity
  	  #	
  	  class OrderItemCustomer
  	  	include DataMapper::Resource

        storage_names[:default] = 'orderds_order_item_customers' 

        property :id, Serial

        property :customer_name, String, length: 80
        property :customer_surname, String, length: 80
        property :customer_document_id, String, length: 50
        property :customer_phone, String, length: 15
        property :customer_email, String, length: 40
        property :customer_height, String, :length => 20
        property :customer_weight, String, :length => 20

        property :customer_allergies_or_intolerances, Text

        belongs_to :order_item, 'OrderItem', :child_key => [:order_item_id]

      end
    end
  end
end  