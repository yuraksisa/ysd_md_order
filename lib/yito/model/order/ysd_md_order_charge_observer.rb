require 'dm-observer' unless defined?DataMapper::Observer
require 'ysd_md_charge' unless defined?Payments::Charge

module Yito
  module Model
    module Order
      #
      # Observes changes on the charge tied to the order to update the order
      # status depending on the charge status change
      #
      # - If the charge status is set to done, the order status is set to
      #   confirmed
      #
      # - If the charge status is set to denied, the order status is set to
      #   pending_confirmation
      #	
      class OrderChargeObserver
        include DataMapper::Observer

        observe Payments::Charge
    
        #
        # After updating a charge
        #
        #  - Updates the order payment_status
        #  - Updates the total_paid and total_pending quantities
        #
        #  * Confirms the order if the status is pending_confirmation
        #
        after :update do |charge|

          if charge.charge_source.is_a?Yito::Model::Order::OrderCharge 
            order = charge.charge_source.order
            case charge.status
              when :done
                order.total_paid += charge.amount
                order.total_pending -= charge.amount
                if (order.total_pending == 0)
                  order.payment_status = :total
                else
                  order.payment_status = :deposit
                end
                if order.status == :pending_confirmation           
                  order.confirm
                else
                  order.save
                end 
              when :denied
                # None
            end
          end
      
        end
      end
    end
  end
end