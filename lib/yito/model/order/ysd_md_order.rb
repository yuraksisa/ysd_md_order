require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Order
  	  class Order
  	  	include DataMapper::Resource
        include Yito::Model::UserAgentData
        extend Yito::Model::Order::NotificationTemplates
        include Yito::Model::Order::Notifications
        extend Yito::Model::Booking::ActivityQueries
        extend Yito::Model::Finder        

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
        property :customer_email, String, :field => 'customer_email', :length => 40
        property :customer_phone, String, :field => 'customer_phone', :length => 15
        property :customer_mobile_phone, String, :field => 'customer_mobile_phone', :length => 15
        property :customer_language, String, :field => 'customer_language', :length => 3
        belongs_to :customer_address, 'LocationDataSystem::Address', :required => false # The customer address

        property :comments, Text
        property :notes, Text

        has n, :order_items, 'OrderItem', :constraint => :destroy

        has n, :order_item_customers, 'OrderItemCustomer', :through => :order_items
        has n, :order_item_resources, 'OrderItemResource', :through => :order_items

        property :free_access_id, String, :field => 'free_access_id', :length => 32, :unique_index => :booking_free_access_id_index

        property :status, Enum[:pending_confirmation, :confirmed,  
           :cancelled], :field => 'status', :default => :pending_confirmation
        property :payment_status, Enum[:none, :deposit, :total, :refunded], 
           :field => 'payment_status', :default => :none

        belongs_to :rental_location, 'Yito::Model::Booking::RentalLocation', required: false

        # ------------------- Hooks --------------------------------------------------------

        #
        # Before create hook (initilize fields)
        #
        before :create do |order|
          order.creation_date = Time.now unless order.creation_date
          order.free_access_id =
              Digest::MD5.hexdigest("#{rand}#{customer_name}#{customer_surname}#{customer_email}#{rand}")
        end        
        
        # ------------------- Class methods ------------------------------------------------

        #
        # Creates an order from a shopping cart
        #
        def self.create_from_shopping_cart(shopping_cart)

          order = Order.new
          order.source = shopping_cart.source
          order.total_cost = shopping_cart.total_cost
          order.total_paid = 0
          order.total_pending = shopping_cart.total_cost
          order.customer_language = shopping_cart.customer_language

          # Build the order items
          shopping_cart.shopping_cart_items.each do |shopping_cart_item|
            order_item = OrderItem.new
            order_item.date = shopping_cart_item.date
            order_item.time = shopping_cart_item.time
            order_item.item_id = shopping_cart_item.item_id
            order_item.item_description = shopping_cart_item.item_description
            order_item.item_description_customer_translation = shopping_cart_item.item_description_customer_translation
            order_item.item_unit_cost = shopping_cart_item.item_unit_cost
            order_item.quantity = shopping_cart_item.quantity
            order_item.item_cost = shopping_cart_item.item_cost
            order_item.item_price_type = shopping_cart_item.item_price_type
            order_item.item_price_description = shopping_cart_item.item_price_description
            order_item.custom_customers_pickup_place = shopping_cart_item.custom_customers_pickup_place
            order_item.customers_pickup_place = shopping_cart_item.customers_pickup_place
            order_item.request_customer_information = shopping_cart_item.request_customer_information
            order_item.request_customer_address = shopping_cart_item.request_customer_address
            order_item.request_customer_document_id = shopping_cart_item.request_customer_document_id
            order_item.request_customer_phone = shopping_cart_item.request_customer_phone
            order_item.request_customer_email = shopping_cart_item.request_customer_email
            order_item.request_customer_height = shopping_cart_item.request_customer_height
            order_item.request_customer_weight = shopping_cart_item.request_customer_weight
            order_item.request_customer_allergies_intolerances = shopping_cart_item.request_customer_allergies_intolerances
            order_item.uses_planning_resources = shopping_cart_item.uses_planning_resources
            order_item.item_payment_setup = shopping_cart_item.item_payment_setup
            order_item.item_custom_payment_allow_deposit_payment = shopping_cart_item.item_custom_payment_allow_deposit_payment
            order_item.item_custom_payment_deposit = shopping_cart_item.item_custom_payment_deposit
            order_item.item_custom_payment_allow_total_payment = shopping_cart_item.item_custom_payment_allow_total_payment
            order_item.order = order
            order.order_items << order_item
            shopping_cart_item.shopping_cart_item_customers.each do |shopping_cart_item_customer|
              order_item_customer = OrderItemCustomer.new
              order_item_customer.order_item = order_item
              order_item_customer.customer_name = shopping_cart_item_customer.customer_name
              order_item_customer.customer_surname = shopping_cart_item_customer.customer_surname
              order_item_customer.customer_document_id = shopping_cart_item_customer.customer_document_id
              order_item_customer.customer_phone = shopping_cart_item_customer.customer_phone
              order_item_customer.customer_email = shopping_cart_item_customer.customer_email
              order_item_customer.customer_height = shopping_cart_item_customer.customer_height
              order_item_customer.customer_weight = shopping_cart_item_customer.customer_weight
              order_item_customer.customer_allergies_or_intolerances = shopping_cart_item_customer.customer_allergies_or_intolerances
              order_item.order_item_customers << order_item_customer
            end
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
        # Get the occupation of and item_id in a date and a time
        #
        def self.occupation(item_id, date, time, price_type=nil)

          if price_type.nil?
            query = <<-QUERY
                      select item_id, date, time, item_price_type, sum(quantity) as occupation
                      from orderds_order_items o_i
                      join orderds_orders o on o.id = o_i.order_id
                      where item_id = ? and date = ? and time = ? and
                            o.status not in (3)
                      group by item_id, date, time, item_price_type
            QUERY
            result = repository.adapter.select(query, item_id, date, time)
          else
            query = <<-QUERY
                      select item_id, date, time, item_price_type, sum(quantity) as occupation
                      from orderds_order_items o_i
                      join orderds_orders o on o.id = o_i.order_id
                      where item_id = ? and date = ? and time = ? and item_price_type = ? and
                            o.status not in (3)
                      group by item_id, date, time, item_price_type
            QUERY

            result = repository.adapter.select(query, item_id, date, time, price_type)
          end

          return result

        end

        # ------------------- Instance methods ---------------------------------------------

        #
        # Adds an item to the order
        # 
        def add_item(date, time, item_id, item_description, item_price_type,
                     quantity, item_unit_cost, item_price_description,
                     custom_customers_pickup_place, customers_pickup_place,
                     options={})

          # Check if item exists
          order_item = ::Yito::Model::Order::OrderItem.first(
                                 order_id: self.id, date: date, time: time,
                                 item_id: item_id, item_price_type: item_price_type)
          
          begin
            if order_item
              inc_cost = (quantity * order_item.item_unit_cost)
              order_item.quantity += quantity
              order_item.item_cost += inc_cost
              order_item.save
              self.total_cost += inc_cost
              self.total_pending = 0 if self.total_pending.nil?
              self.total_pending += inc_cost
              self.save
            else
              # Get the product translation
              if product = ::Yito::Model::Booking::Activity.get(item_id)
                product_customer_translation = product.translate(self.customer_language)
                item_description_customer_translation = (product_customer_translation.nil? ? item_description : product_customer_translation.name)
              else
                item_description_customer_translation = item_description
              end
              # Create the order item
              order_item = ::Yito::Model::Order::OrderItem.new
              order_item.order = self
              order_item.date = date
              order_item.time = time
              order_item.item_id = item_id
              order_item.item_description = item_description
              order_item.item_description_customer_translation = item_description_customer_translation
              order_item.item_price_description = item_price_description
              order_item.item_price_type = item_price_type
              order_item.quantity = quantity
              order_item.item_unit_cost = item_unit_cost
              order_item.item_cost = order_item.item_unit_cost * order_item.quantity

              order_item.custom_customers_pickup_place = custom_customers_pickup_place
              order_item.customers_pickup_place = customers_pickup_place

              order_item.request_customer_information = options[:request_customer_information] if options.has_key?(:request_customer_information)
              order_item.request_customer_address = options[:request_customer_address] if options.has_key?(:request_customer_address)
              order_item.request_customer_document_id = options[:request_customer_document_id] if options.has_key?(:request_customer_document_id)
              order_item.request_customer_phone = options[:request_customer_phone] if options.has_key?(:request_customer_phone)
              order_item.request_customer_email = options[:request_customer_email] if options.has_key?(:request_customer_email)
              order_item.request_customer_height = options[:request_customer_height] if options.has_key?(:request_customer_height)
              order_item.request_customer_weight = options[:request_customer_weight] if options.has_key?(:request_customer_weight)
              order_item.request_customer_allergies_intolerances = options[:request_customer_allergies_intolerances] if options.has_key?(:request_customer_allergies_intolerances)
              order_item.uses_planning_resources = options[:uses_planning_resources] if options.has_key?(:uses_planning_resources)

              order_item.item_custom_payment_allow_deposit_payment = options[:custom_payment_allow_deposit_payment]  if options.has_key?(:custom_payment_allow_deposit_payment)
              order_item.item_custom_payment_deposit = options[:custom_payment_deposit]  if options.has_key?(:custom_payment_deposit)
              order_item.item_custom_payment_allow_total_payment = options[:custom_payment_allow_total_payment]  if options.has_key?(:custom_payment_allow_total_payment)
              order_item.item_allow_request_reservation = options[:allow_request_reservation] if options.has_key?(:allow_request_reservation)

              order_item.save

              # Create order item customers
              if order_item.request_customer_information
                (1..order_item.quantity).each do |item|
                   order_item_customer = ::Yito::Model::Order::OrderItemCustomer.new
                   # The first item apply the order customer data
                   if item==1
                     order_item_customer.customer_name = customer_name
                     order_item_customer.customer_surname = customer_surname
                     order_item_customer.customer_email = customer_email
                     order_item_customer.customer_phone = customer_phone
                   end
                   order_item_customer.order_item = order_item
                   order_item_customer.save
                end
              end

              self.total_cost += order_item.item_cost
              self.total_pending = 0 if self.total_pending.nil?
              self.total_pending += order_item.item_cost
              self.save
            end
          rescue DataMapper::SaveFailureError => error
            p "Error adding item. #{order_item.errors.inspect} ** #{self.errors.inspect}"
            raise error
          end
        end

        #
        # Get the item quantity in an order 
        #
        def item_quantity(item_id, item_price_type)
          the_items = order_items.select do |item|
                       item.item_id == item_id && item.item_price_type == item_price_type
                     end
          if the_items.size > 0
            return the_items.first.quantity
          else
            return 0
          end
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
        # Check if any of the order items requires customer address
        #
        def request_customer_address?
          order_items.any? { |item| item.request_customer_address }
        end

        alias_method :request_customer_address, :request_customer_address?
        
        #
        # Check if the any of the order items requires customer information
        #
        def request_customer_information?
          order_items.any? { |item| item.request_customer_information }
        end
        
        alias_method :request_customer_information, :request_customer_information?
        
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
        # Check if the deposit can be paid
        #
        def can_pay_deposit?

          conf_allow_deposit_payment = order_items.any? { |order_item| order_item.item_custom_payment_allow_deposit_payment }
          can_pay_deposit = (status != :cancelled) && total_paid == 0 &&
                            ((conf_allow_deposit_payment && !expired? && payment_cadence?) || self.force_allow_deposit_payment)

          return can_pay_deposit

        end

        alias_method :can_pay_deposit, :can_pay_deposit?

        #
        # Check if the total can be paid
        #
        def can_pay_total?
          conf_allow_total_payment = order_items.any? { |order_item| order_item.item_custom_payment_allow_total_payment }
          can_pay_total = (status != :cancelled) && total_paid == 0 &&
                          ((conf_allow_total_payment && !expired? && payment_cadence?) || self.force_allow_payment)

          return can_pay_total
        end

        alias_method :can_pay_total, :can_pay_total?

        #
        # Check if the pending can be paid
        #
        def can_pay_pending?
          conf_allow_total_payment = order_items.any? { |order_item| order_item.item_custom_payment_allow_total_payment }
          can_pay_pending = (status != :cancelled) && total_paid > 0 && total_pending > 0 &&
              ((conf_allow_total_payment && !expired? && payment_cadence?) || self.force_allow_payment)

          return can_pay_pending
        end

        alias_method :can_pay_pending, :can_pay_pending?

        def payment_cadence?
          result = true
          order_items.each do |item|
            result = result && Order.payment_cadence?(item.date) unless item.date.nil?
          end
          return result
        end

        #
        # Check if the reservation is within the cadence period
        #
        def self.payment_cadence?(date_from)

           conf_payment_cadence = SystemConfiguration::Variable.get_value('order.payment_cadence', '0').to_i

           cadence_from = DateTime.parse("#{date_from.strftime('%Y-%m-%d')}T00:00:00")
           diff_in_hours = (cadence_from.to_time - DateTime.now.to_time) / 3600
           diff_in_hours >= conf_payment_cadence
         
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
            relationships.store(:customer_address, {})
            relationships.store(:order_items, {methods: [:customers, :resources]})
            methods = options[:methods] || []
            methods << :is_expired
            methods << :can_pay_deposit
            methods << :can_pay_total
            methods << :can_pay_pending
            methods << :request_customer_address
            super(options.merge({:relationships => relationships, :methods => methods}))
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