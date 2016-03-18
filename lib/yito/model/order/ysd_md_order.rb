require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Order
  	  class Order
  	  	include DataMapper::Resource
        include Yito::Model::UserAgentData
        extend Yito::Model::Order::NotificationTemplates
        include Yito::Model::Order::Notifications

        storage_names[:default] = 'orderds_orders' 
  	  	
        property :id, Serial
        
        property :creation_date, DateTime, :field => 'creation_date'  # The creation date
        property :created_by_manager, Boolean, :field => 'created_by_manager', :default => false
        property :source, String, :field => 'source', :length => 50   # Where does the booking come from

        property :total_cost, Decimal, :field => 'total_cost', :scale => 2, :precision => 10, :default => 0
        property :total_paid, Decimal, :field => 'total_paid', :scale => 2, :precision => 10, :default => 0
        property :total_pending, Decimal, :field => 'total_pending', :scale => 2, :precision => 10, :default => 0
        property :reservation_amount, Decimal, :field => 'reservation_amount', :scale => 2, :precision => 10, :default => 0

        property :force_allow_payment, Boolean, :field => 'force_allow_payment', :default => false
        property :force_allow_deposit_payment, Boolean, :field => 'force_allow_deposit_payment', :default => false
   
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
        # Creates an order from a shopping cart
        #
        def self.create_from_shopping_cart(shopping_cart)

          order = Order.new
          order.source = shopping_cart.source
          order.total_cost = shopping_cart.total_cost
          order.total_paid = 0
          order.total_pending = shopping_cart.total_cost
          #order.reservation_amount =

          # Build the order items
          shopping_cart.shopping_cart_items.each do |shopping_cart_item| 
            order_item = OrderItem.new
            order_item.date = shopping_cart_item.date 
            order_item.time = shopping_cart_item.time 
            order_item.item_id = shopping_cart_item.item_id
            order_item.item_description = shopping_cart_item.item_description
            order_item.item_unit_cost = shopping_cart_item.item_unit_cost
            order_item.quantity = shopping_cart_item.quantity
            order_item.item_cost = shopping_cart_item.item_cost
            order_item.item_price_type = shopping_cart_item.item_price_type
            order_item.item_price_description = shopping_cart_item.item_price_description
            order_item.order = order
            order.order_items << order_item
          end
          
          return order

        end

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
        # Get the order items group by date, time and item_id
        #
        def order_items_group_by_date_time_item_id
          result = {}
          idx = 1
          last_order_item = nil
          order_items.each do |order_item|
            if last_order_item.nil? or 
               (last_order_item.date != order_item.date or
                last_order_item.time != order_item.time or 
                last_order_item.item_id != order_item.item_id)
              result.store(idx, {items: [order_item], total: order_item.item_cost})
              idx += 1
              last_order_item = order_item
            else
              the_data = result[idx-1]
              the_data[:items] << order_item
              the_data[:total] += order_item.item_cost
            end
          end
          result
        end

        #
        # Creates an online charge 
        #
        # @param [String] payment to be created : deposit, total, pending
        # @param [String] payment method id
        #
        # @return [Charge] The created charge
        #
        def create_online_charge!(charge_payment, charge_payment_method_id)
       
          if total_pending > 0 and 
            charge_payment_method = Payments::PaymentMethod.get(charge_payment_method_id.to_sym) and
            not charge_payment_method.is_a?Payments::OfflinePaymentMethod 

            amount = case charge_payment.to_sym
                       when :deposit
                         reservation_amount
                       when :total
                         total_cost
                       when :pending
                         total_pending
                     end
 
            charge = new_charge!(charge_payment_method_id, amount) if amount > 0
            save
            return charge
          end 

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
            notify_manager_confirmation
            notify_customer            
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
           conf_item_hold_time = SystemConfiguration::Variable.get_value('order.item_hold_time', '0').to_i
           hold_time_diff_in_hours = (DateTime.now.to_time - self.creation_date.to_time) / 3600
           expired = (hold_time_diff_in_hours > conf_item_hold_time)
           expired and (!force_allow_payment or !force_allow_deposit_payment)
        end

        alias_method :is_expired, :expired?

        #
        # Check if the customer can pay for the order
        #
        def can_pay?

          conf_allow_total_payment = SystemConfiguration::Variable.get_value('order.allow_total_payment','false').to_bool
          conf_allow_deposit_payment = SystemConfiguration::Variable.get_value('order.allow_deposit_payment','false').to_bool

          can_pay = (total_pending > 0 and status != :cancelled) 

          if can_pay
            if self.total_paid > 0 
              can_pay = (can_pay and (conf_allow_total_payment or force_allow_payment)) 
            else  
              can_pay = (can_pay and ((conf_allow_deposit_payment and !self.expired?) or force_allow_deposit_payment))
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

        #
        # Get the occupation of and item_id in a date and a time
        #
        def self.occupation(item_id, date, time, price_type=nil)

          if price_type.nil?
            query = <<-QUERY
                      select item_id, date, time, sum(quantity) as occupation
                      from orderds_order_items
                      where item_id = ? and date = ? and time = ?
                      group by item_id, date, time
                    QUERY
            repository.adapter.select(query, item_id, date, time).first
          else
            query = <<-QUERY
                      select item_id, date, time, item_price_type, sum(quantity) as occupation
                      from orderds_order_items
                      where item_id = ? and date = ? and time = ? and item_price_type = ?
                      group by item_id, date, time, item_price_type
                    QUERY

            repository.adapter.select(query, item_id, date, time, price_type).first
          end

        end

        private
     
        #
        # Creates a new charge for the order
        #
        # @param [String] payment_method_id
        # @param [Number] amount
        #
        # @return [Payments::Charge] The created charge
        #
        def new_charge!(charge_payment_method_id, charge_amount)
          charge = Payments::Charge.create({:date => Time.now,
              :amount => charge_amount, 
              :payment_method_id => charge_payment_method_id,
              :currency => SystemConfiguration::Variable.get_value('payments.default_currency', 'EUR') }) 
          self.charges << charge
          return charge
        end

      end
    end
  end
end