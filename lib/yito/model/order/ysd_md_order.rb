require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Order
  	  class Order
  	  	include DataMapper::Resource

        storage_names[:default] = 'orderds_orders' 
  	  	
        property :id, Serial
        
        property :creation_date, DateTime, :field => 'creation_date'  # The creation date
        property :created_by_manager, Boolean, :field => 'created_by_manager', :default => false
        property :source, String, :field => 'source', :length => 50   # Where does the booking come from

        property :total_cost, Decimal, :field => 'total_cost', :scale => 2, :precision => 10, :default => 0
        property :total_paid, Decimal, :field => 'total_paid', :scale => 2, :precision => 10, :default => 0
        property :total_pending, Decimal, :field => 'total_pending', :scale => 2, :precision => 10, :default => 0

        property :force_allow_payment, Boolean, :field => 'force_allow_payment', :default => false
   
        has n, :order_charges, 'OrderCharge', :child_key => [:order_id], :parent_key => [:id]
        has n, :charges, 'Payments::Charge', :through => :order_charges

        property :customer_name, String, :field => 'customer_name', :required => true, :length => 40
        property :customer_surname, String, :field => 'customer_surname', :required => true, :length => 40
        property :customer_email, String, :field => 'customer_email', :required => true, :length => 40
        property :customer_phone, String, :field => 'customer_phone', :required => true, :length => 15 
        property :customer_mobile_phone, String, :field => 'customer_mobile_phone', :length => 15
        property :customer_language, String, :field => 'customer_language', :length => 3

        property :comments, Text
        property :notes, Text

        has n, :order_items, 'OrderItem', :constraint => :destroy

        property :free_access_id, String, :field => 'free_access_id', :length => 32, :unique_index => :booking_free_access_id_index

        property :status, Enum[:pending_confirmation, :confirmed,  
           :cancelled], :field => 'status', :default => :pending_confirmation
        property :payment_status, Enum[:none, :deposit, :total, :refunded], 
           :field => 'payment_status', :default => :none

        #
        # Get a order by its free access id
        #
        # @parm [String] free access id
        # @return [Order] 
        def self.get_by_free_access_id(free_id)
          first({:free_access_id => free_id})
        end 

        #
        # Before create hook (initilize fields)
        #
        before :create do |order|
          order.creation_date = Time.now unless order.creation_date
          order.free_access_id = 
            Digest::MD5.hexdigest("#{rand}#{customer_name}#{customer_surname}#{customer_email}#{rand}")
        end

        #
        # Confirms the booking
        #
        # An order can only be confirmed if it's pending confirmation 
        # and contains a done charge
        #
        # @return [Order]
        #
        def confirm
          if status == :pending_confirmation and
             not charges.select { |charge| charge.status == :done }.empty?
            self.status = :confirmed
            order_items.each do |order_item|
              order_item.status = :confirmed 
            end
            save
          else
            p "Could not confirm order #{id} #{status}"
          end
       
          self
        end

        #
        # Confirm the order without checking the charges
        #
        # @return [Order]
        #
        def confirm!
          if status == :pending_confirmation 
            update(:status => :confirmed)
            order_items.each do |order_item|
              order_item.update(:status => :confirmed)
            end
          end
          self
        end


        #
        # Cancels an order
        #
        # An order can only be cancelled if it isn't already cancelled
        # 
        # @return [Order]
        #
        def cancel
      
          unless status == :cancelled
            transaction do 
              if total_paid > 0
                update(:status => :cancelled, :payment_status => :refunded, :total_paid => 0, :total_pending => total_cost)
              else 
                update(:status => :cancelled)
              end
              order_items.each do |order_item|
                order_item.update(:status => :cancelled)
              end                        
              charges.each do |charge|
                charge.refund
              end
            end
          end

          self
        end

        #
        # Check if the order has expired
        #
        def expired?
           conf_item_hold_time = SystemConfiguration::Variable.get_value('booking.item_hold_time', '0').to_i
           hold_time_diff_in_hours = (DateTime.now.to_time - self.creation_date.to_time) / 3600
           expired = (hold_time_diff_in_hours > conf_item_hold_time)
           expired and !force_allow_payment
        end

        alias_method :is_expired, :expired?

        #
        # Check if the customer can pay for the order
        #
        def can_pay?

          conf_payment_enabled = SystemConfiguration::Variable.get_value('booking.payment', 'false').to_bool
          conf_allow_total_payment = SystemConfiguration::Variable.get_value('booking.allow_total_payment','false').to_bool

          can_pay = (total_pending > 0 and status != :cancelled and (conf_payment_enabled or force_allow_payment)) 

          if can_pay
            if self.total_paid > 0 # It's not the first payment
              can_pay = (can_pay and conf_allow_total_payment) 
            else  # It's the first payment (check expiration)
              can_pay = (can_pay and !self.expired?)
            end
          end            

          return can_pay

        end

        #
        # Check if the reservation is within the cadence period
        #
        def self.payment_cadence?(date_from)

           conf_payment_cadence = SystemConfiguration::Variable.get_value('booking.payment_cadence', '0').to_i

           cadence_from = DateTime.parse("#{date_from.strftime('%Y-%m-%d')}T00:00:00")
           cadence_payment = (cadence_from.to_time - DateTime.now.to_time) / 3600
           cadence_payment > conf_payment_cadence

        end

        #
        # Get the charge item detail
        #
        def charge_item_detail
    
          detail = ""
          order_items.each do |item|
            detail << "#{item.item_description} #{item.quantity},"
          end
          
          return detail

        end

        #
        # Exporting to json
        #
        def as_json(options={})

         if options.has_key?(:only)
           super(options)
         else
           relationships = options[:relationships] || {}
           relationships.store(:charges, {})
           relationships.store(:order_items, {})
           methods = options[:methods] || []
           methods << :is_expired
           super(options.merge({:relationships => relationships, :methods => methods}))
         end

     end


      end
    end
  end
end