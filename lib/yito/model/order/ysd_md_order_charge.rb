require 'data_mapper' unless defined?DataMapper
require 'ysd_md_payment' unless defined?Payments::Charge

module Yito
  module Model
    module Order
      class OrderCharge
        include DataMapper::Resource

        storage_names[:default] = 'orderds_order_charges'

        belongs_to :order, 'Order', :child_key => [:order_id], :parent_key => [:id], :key => true
        belongs_to :charge, 'Payments::Charge', :child_key => [:charge_id], :parent_key => [:id], :key => true
    
        #
        # Retrieve the order associated with a charge
        # 
        def self.order_from_charge(charge_id)

          if order_charge = first(:charge => {:id => charge_id })
            order_charge.order
          end

        end 

        #
        # Integration with charges (return the charge detail)
        #
        # @return [Array]
        def charge_detail
      
          @charge_detail ||= if order 
                               build_full_charge_detail
                             else
                               []
                             end

        end
    
        #
        # Integration with charges. When the charge is going to be charged, notifies
        # the sources
        #
        def charge_in_process

          # None

        end
    
        #
        # Integration with charges
        #
        def charge_source_description
      
          if booking and booking.id
            ::Yito::Model::Order.r18n.t.order_model.charge_description(order.id)       
          end

        end
     
        #
        # Integration with charges
        # 
        def charge_source_url
          if order and order.id
            "/admin/order/orders/#{order.id}"
          end
        end

        def as_json(opts={})

          methods = opts[:methods] || []
          methods << :charge_source_description
          methods << :charge_source_url

          super(opts.merge(:methods => methods))

        end


        private 
    
        #
        # Builds a full charge detail
        #
        # @return [Array]
        def build_full_charge_detail

          charge_detail = []
          order.order_items.each do |order_item|
            charge_detail << {:item_reference => order_item.item_id,
                              :item_description => order.charge_item_detail,
                              :item_units => order_item.quantity,
                              :item_price => order_item.item_cost}
          end
      
          return charge_detail
        end
      end
    end
  end
end

module Payments
  class Charge
    has 1, :order_charge_source, 'Yito::Model::Order::OrderCharge', :constraint => :destroy
  end
end