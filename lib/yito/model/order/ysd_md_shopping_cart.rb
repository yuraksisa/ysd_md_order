require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Order
  	  class ShoppingCart
  	  	include DataMapper::Resource

        storage_names[:default] = 'orderds_shopping_carts' 
  	  	
        property :id, Serial
        
        property :creation_date, DateTime 
        property :created_by_manager, Boolean, :default => false
        property :source, String, :length => 50 
        property :total_cost, Decimal, :scale => 2, :precision => 10, :default => 0
        property :comments, Text

        property :customer_name, String, :length => 40
        property :customer_surname, String, :length => 40
        property :customer_email, String, :length => 40
        property :customer_phone, String, :length => 15 
        property :customer_mobile_phone, String, :length => 15
        property :customer_language, String, :length => 3
        belongs_to :customer_address, 'LocationDataSystem::Address', :required => false # The customer address

        has n, :shopping_cart_items, 'ShoppingCartItem', :constraint => :destroy

        property :free_access_id, String, :field => 'free_access_id', :length => 32, :unique_index => :shopping_cart_free_access_id_index

        property :promotion_code, String, :length => 256

        # ------------------      Hooks    ---------------------------------

        #
        # Before create hook (initilize fields)
        #
        before :create do |shopping_cart|
          shopping_cart.creation_date = DateTime.now unless shopping_cart.creation_date
          alphabet = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
          random_string = (0...50).map { alphabet[rand(alphabet.length)] }.join
          shopping_cart.free_access_id =
              Digest::MD5.hexdigest("#{rand}#{shopping_cart.creation_date.to_s}#{random_string}#{rand}")
        end


        # ------------------ Class methods ---------------------------------

        #
        # Get a shopping cart by its free access id
        #
        # @parm [String] free access id
        # @return [ShoppingCart]
        def self.get_by_free_access_id(free_id)
          first({:free_access_id => free_id})
        end

        # ------------------- Instance methods -----------------------------

        def request_customer_address
          shopping_cart_items.any? { |item| item.request_customer_address }
        end

        def empty?
          shopping_cart_items.empty?
        end

        #
        # Get the shopping cart items group by date, time and item_id
        #
        def shopping_cart_items_group_by_date_time_item_id
          result = {}
          idx = 1
          last_shopping_cart_item = nil
          shopping_cart_items.each do |shopping_cart_item|
            if last_shopping_cart_item.nil? or 
               (last_shopping_cart_item.date != shopping_cart_item.date or
                last_shopping_cart_item.time != shopping_cart_item.time or 
                last_shopping_cart_item.item_id != shopping_cart_item.item_id)
              result.store(idx, {items: [shopping_cart_item], total: shopping_cart_item.item_cost})
              idx += 1
              last_shopping_cart_item = shopping_cart_item
            else
              the_data = result[idx-1]
              the_data[:items] << shopping_cart_item
              the_data[:total] += shopping_cart_item.item_cost
            end
          end
          result
        end
        
        #
        # Get the item count
        #
        def items_count
          shopping_cart_items_group_by_date_time_item_id.size
        end
        
        #
        # Get the item quantity in a shopping cart 
        #
        def item_quantity(item_id, item_price_type)
          the_items = shopping_cart_items.select do |item|
                       item.item_id == item_id && item.item_price_type == item_price_type
                     end
          if the_items.size > 0
            return the_items.first.quantity
          else
            return 0
          end
        end

        #
        # Adds an item to the shopping cart
        # 
        def add_item(date, time, item_id, item_description, item_price_type,
                     quantity, item_unit_cost, item_price_description,
                     custom_customers_pickup_place, customers_pickup_place,
                     options={})

          # Check if item exists
          shopping_cart_item = ::Yito::Model::Order::ShoppingCartItem.first(
                                 shopping_cart_id: self.id, date: date, time: time,
                                 item_id: item_id, item_price_type: item_price_type)
          
          begin
          if shopping_cart_item
            inc_cost = (quantity * shopping_cart_item.item_unit_cost)
            shopping_cart_item.quantity += quantity
            shopping_cart_item.item_cost += inc_cost
            shopping_cart_item.save
            self.total_cost += inc_cost
            self.save
            # Create shopping cart item customers
            if shopping_cart_item.request_customer_information
              (1..quantity).each do |item|
                shopping_cart_item_customer = ::Yito::Model::Order::ShoppingCartItemCustomer.new 
                shopping_cart_item_customer.shopping_cart_item = shopping_cart_item
                shopping_cart_item_customer.save
              end
            end  
          else
            # Get the product translation
            if product = ::Yito::Model::Booking::Activity.get(item_id)
              product_customer_translation = product.translate(self.customer_language)
              item_description_customer_translation = (product_customer_translation.nil? ? item_description : product_customer_translation.name)
            else
              item_description_customer_translation = item_description
            end
            shopping_cart_item = ::Yito::Model::Order::ShoppingCartItem.new
            shopping_cart_item.shopping_cart = self
            shopping_cart_item.date = date
            shopping_cart_item.time = time
            shopping_cart_item.item_id = item_id
            shopping_cart_item.item_description = item_description
            shopping_cart_item.item_description_customer_translation = item_description_customer_translation
            shopping_cart_item.item_price_description = item_price_description
            shopping_cart_item.item_price_type = item_price_type
            shopping_cart_item.quantity = quantity
            shopping_cart_item.item_unit_cost = item_unit_cost
            shopping_cart_item.item_cost = shopping_cart_item.item_unit_cost * shopping_cart_item.quantity
            
            shopping_cart_item.custom_customers_pickup_place = custom_customers_pickup_place
            shopping_cart_item.customers_pickup_place = customers_pickup_place

            shopping_cart_item.request_customer_information = options[:request_customer_information] if options.has_key?(:request_customer_information)
            shopping_cart_item.request_customer_address = options[:request_customer_address] if options.has_key?(:request_customer_address)
            shopping_cart_item.request_customer_document_id = options[:request_customer_document_id] if options.has_key?(:request_customer_document_id)
            shopping_cart_item.request_customer_phone = options[:request_customer_phone] if options.has_key?(:request_customer_phone)
            shopping_cart_item.request_customer_email = options[:request_customer_email] if options.has_key?(:request_customer_email)
            shopping_cart_item.request_customer_height = options[:request_customer_height] if options.has_key?(:request_customer_height)
            shopping_cart_item.request_customer_weight = options[:request_customer_weight] if options.has_key?(:request_customer_weight)
            shopping_cart_item.request_customer_allergies_intolerances = options[:request_customer_allergies_intolerances] if options.has_key?(:request_customer_allergies_intolerances)
            shopping_cart_item.uses_planning_resources = options[:uses_planning_resources] if options.has_key?(:uses_planning_resources)
            shopping_cart_item.own_contract = options[:own_contract] if options.has_key?(:own_contract)
            shopping_cart_item.item_allow_request_reservation = options[:allow_request_reservation] if options.has_key?(:allow_request_reservation)
            shopping_cart_item.item_custom_payment_allow_deposit_payment = options[:custom_payment_allow_deposit_payment]  if options.has_key?(:custom_payment_allow_deposit_payment)
            shopping_cart_item.item_custom_payment_deposit = options[:custom_payment_deposit]  if options.has_key?(:custom_payment_deposit)
            shopping_cart_item.item_custom_payment_allow_total_payment = options[:custom_payment_allow_total_payment]  if options.has_key?(:custom_payment_allow_total_payment)

            shopping_cart_item.save

            # Create shopping cart item customers
            if shopping_cart_item.request_customer_information
              (1..shopping_cart_item.quantity).each do |item|
                 shopping_cart_item_customer = ::Yito::Model::Order::ShoppingCartItemCustomer.new
                 if item == 1
                   shopping_cart_item_customer.customer_name = customer_name
                   shopping_cart_item_customer.customer_surname = customer_surname
                   shopping_cart_item_customer.customer_email = customer_email
                   shopping_cart_item_customer.customer_phone = customer_phone
                 end
                 shopping_cart_item_customer.shopping_cart_item = shopping_cart_item
                 shopping_cart_item_customer.save
              end
            end

            # Updates the shopping cart

            self.total_cost += shopping_cart_item.item_cost
            self.save
          end
          rescue DataMapper::SaveFailureError => error
            p "Error adding item. #{shopping_cart_item.errors.inspect} ** #{self.errors.inspect}"
            raise error
          end
        end
        
        #
        # Remove an item from the shopping cart
        #
        def remove_item(date,time,item_id)

          shopping_cart_items = ::Yito::Model::Order::ShoppingCartItem.all(
              shopping_cart_id: self.id, date: date, time: time,
              item_id: item_id)
          
          if shopping_cart_items.size > 0
            shopping_cart_items.each do |shopping_cart_item|
              shopping_cart_item.destroy
              self.total_cost -= shopping_cart_item.item_cost
            end
            self.save
          end

        end

        #
        # Check if a request (without payment can be made)
        #
        def can_make_request?

          #SystemConfiguration::Variable.get_value('order.request_reservations', 'false').to_bool
          shopping_cart_items.any? { |shopping_cart_item| shopping_cart_item.item_allow_request_reservation }
          
        end

        alias_method :can_make_request, :can_make_request?
        
        #
        # Check if the deposit can be paid
        #
        def can_pay_deposit?

          conf_allow_deposit_payment = shopping_cart_items.any? { |shopping_cart_item| shopping_cart_item.item_custom_payment_allow_deposit_payment }
          can_pay_deposit = conf_allow_deposit_payment && payment_cadence?

        end

        alias_method :can_pay_deposit, :can_pay_deposit?

        #
        # Check if the total can be paid
        #
        def can_pay_total?

          conf_allow_total_payment = shopping_cart_items.any? { |shopping_cart_item| shopping_cart_item.item_custom_payment_allow_total_payment }
          can_pay_total = conf_allow_total_payment && payment_cadence?

        end

        alias_method :can_pay_total, :can_pay_total?

        #
        # Check if all the shopping cart items are in payment cadence
        #
        def payment_cadence?

          result = true
          shopping_cart_items.each do |item|
            result = result && Order.payment_cadence?(item.date) unless item.date.nil?
          end
          return result
          
        end

      end
    end
  end
end