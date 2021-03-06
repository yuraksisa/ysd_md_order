require 'ysd_service_postal' unless defined?ServicePostal
require 'ysd_md_cms' unless defined?ContentManagerSystem::Template
require 'dm-core'
require 'delayed_job'

module Yito
  module Model
    module Order
      module Notifier
    
        #
        # Notifies the manager that a new request has been received
        #
        def self.notify_manager(to, subject, message, order_id)
      
          PostalService.post(build_message(message).merge(:to => to, :subject => subject))
  
          if order = ::Yito::Model::Order::Order.get(order_id)
            order.update(:manager_notification_sent => true)
          end

        end

        #
        # Notify the manager that a new request is being paid
        #
        def self.notify_manager_pay_now(to, subject, message, order_id)

          PostalService.post(build_message(message).merge(:to => to, :subject => subject))
          if order = ::Yito::Model::Order::Order.get(order_id)
            order.update(:manager_notification_p_n_sent => true)
          end

        end
    
        #
        # Notifies the manager that a request has been confirmed
        #
        def self.notify_manager_confirmation(to, subject, message, order_id)
          PostalService.post(build_message(message).merge(:to => to, :subject => subject))
  
          if order = ::Yito::Model::Order::Order.get(order_id)
            order.update(:manager_confirm_notification_sent => true)
          end

        end 

        #
        # Notifies the customer that a new request has been received
        #
        def self.notify_request_to_customer(to, subject, message, order_id)

          PostalService.post(build_message(message).merge(:to => to, :subject => subject))

          if order = ::Yito::Model::Order::Order.get(order_id)
            order.update(:customer_req_notification_sent => true)
          end

        end
    
        #
        # Notifies the customer that a new request has been received (payment process)
        #
        def self.notify_request_to_customer_pay_now(to, subject, message, order_id)

          PostalService.post(build_message(message).merge(:to => to, :subject => subject))

          if order = ::Yito::Model::Order::Order.get(order_id)
            order.update(:customer_req_notification_p_sent => true)
          end      

        end

        #
        # Notifies the customer when the order is confirmed 
        #
        def self.notify_customer(to, subject, message, order_id)

          PostalService.post(build_message(message).merge(:to => to, :subject => subject))

          if order = ::Yito::Model::Order::Order.get(order_id)
            order.update(:customer_notification_sent => true)
          end

        end

        #
        # Notifies the customer when the payment is enabled
        #
        def self.notify_customer_payment_enabled(to, subject, message, order_id)

          PostalService.post(build_message(message).merge(:to => to, :subject => subject))

          if order = ::Yito::Model::Order::Order.get(order_id)
            order.update(:customer_payment_enabled_sent => true)
          end

        end

        def self.build_message(message)

          post_message = {}
      
          if message.match /<\w+>/
            post_message.store(:html_body, message) 
          else
            post_message.store(:body, message)
          end 
      
          return post_message

        end

      end

      #
      # Notification default templates
      #
      module NotificationTemplates

        #
        # Gets the default template used to notify the booking manager that an user is paying
        #
        def manager_notification_pay_now_template

          file = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "..", 
              "templates", "manager_notification_pay_now_template.erb"))

          File.read(file)

        end


        #
        # Gets the default template used to notify the booking manager
        #
        def manager_notification_template

          file = File.expand_path(File.join(File.dirname(__FILE__), "..","..", "..", "..", 
              "templates", "manager_notification_template.erb"))

          File.read(file)

        end

        #
        # Gets the default template used to notify the confirmation of a booking to the manager
        #
        def manager_confirm_notification_template

          file = File.expand_path(File.join(File.dirname(__FILE__), "..","..", "..", "..", 
            "templates", "manager_confirm_notification_template.erb"))

          File.read(file)

        end

        #
        # Gets the default template used to notify the customer
        #
        def customer_notification_booking_request_template

          file = File.expand_path(File.join(File.dirname(__FILE__), "..","..", "..", "..", 
              "templates", "customer_notification_request_template.erb"))

          File.read(file)

        end 
     
        #
        # Gets the default template used to notify customer pay now
        #
        def customer_notification_request_pay_now_template

          file = File.expand_path(File.join(File.dirname(__FILE__), "..","..", "..", "..", 
              "templates", "customer_notification_pay_now_template.erb"))

          File.read(file)

        end

        #
        # Gets the default template used to notify the customer that the reservation is confirmed
        #
        def customer_notification_booking_confirmed_template

          file = File.expand_path(File.join(File.dirname(__FILE__), "..","..", "..", "..", 
              "templates", "customer_notification_confirmed_template.erb"))

          File.read(file)

        end    

        #
        # Gets the default template used to notify the customer that the payment has been enabled
        #
        def customer_notification_payment_enabled_template

          file = File.expand_path(File.join(File.dirname(__FILE__), "..","..", "..", "..", 
              "templates", "customer_notification_payment_enabled_template.erb"))

          File.read(file)

        end

      end

      #
      # Send notifications to the manager and to the customer
      #
      module Notifications
    
        def self.included(model)
     
          if model.respond_to?(:property)
            model.property :customer_req_notification_sent, DataMapper::Property::Boolean, :field => 'customer_req_notification_sent', :default => false
            model.property :customer_req_notification_p_sent, DataMapper::Property::Boolean, :field => 'customer_req_notification_p_sent', :default => false
            model.property :customer_notification_sent, DataMapper::Property::Boolean, :field => 'customer_notification_sent'
            model.property :customer_payment_enabled_sent, DataMapper::Property::Boolean, :field => 'customer_payment_enabled_sent', :default => false
            model.property :manager_notification_sent, DataMapper::Property::Boolean, :field => 'manager_notification_sent'
            model.property :manager_notification_p_n_sent, DataMapper::Property::Boolean, :field => 'manager_notification_p_n_sent', :default => false
            model.property :manager_confirm_notification_sent, DataMapper::Property::Boolean, :field => 'manager_confirm_notification_sent', :default => false
          end

        end

        #
        # Notifies by email the manager that a new order has been received
        # 
        # The manager address can be set up on booking.notification_email variable
        #
        # It allows to define a custom template naming it as order_manager_notification
        # 
        def notify_manager

          if send_notifications?
            if notification_email = SystemConfiguration::Variable.get_value('booking.notification_email')
              bmn_template = ContentManagerSystem::Template.first(:name => 'order_manager_notification')

              template = if bmn_template
                           ERB.new bmn_template.text
                         else
                           ERB.new Order.manager_notification_template
                         end

              message = template.result(binding)

              Notifier.delay.notify_manager(notification_email,
                ::Yito::Model::Order.r18n(self.customer_language).t.notifications.manager_email_subject.to_s,
                message, self.id)

            end
          end

        end  

        #
        # Notifies by email the booking manager that a new order has been received
        # 
        # The manager address can be set up on booking.notification_email variable
        #
        # It allows to define a custom template naming it as order_manager_notification
        # 
        def notify_manager_pay_now

          if send_notifications?
            if notification_email = SystemConfiguration::Variable.get_value('booking.notification_email')
              bmn_template = ContentManagerSystem::Template.first(:name => 'order_manager_notification_pay_now')

              template = if bmn_template
                           ERB.new bmn_template.text
                         else
                           ERB.new ::Yito::Model::Order.manager_notification_pay_now_template
                         end

              message = template.result(binding)

              Notifier.delay.notify_manager_pay_now(notification_email,
                ::Yito::Model::Order.r18n(self.customer_language).t.notifications.manager_paying_email_subject.to_s,
                message, self.id)

            end
          end

        end
    
        #
        # Notifies by email the booking manager that an order has been confirmed
        # 
        # The manager address can be set up on booking.notification_email variable
        #
        # It allows to define a custom template naming it as booking_manager_notification
        # 
        def notify_manager_confirmation

          if notification_email = SystemConfiguration::Variable.get_value('booking.notification_email')
            bmn_template = ContentManagerSystem::Template.first(:name => 'order_confirmation_manager_notification')

            template = if bmn_template
                         ERB.new bmn_template.text
                       else
                         ERB.new ::Yito::Model::Order.manager_confirm_notification_template
                       end
        
            message = template.result(binding)

            Notifier.delay.notify_manager(notification_email, 
              ::Yito::Model::Order.r18n(self.customer_language).t.notifications.manager_confirmation_email_subject.to_s,
              message,
              self.id)

          end

        end  

        #
        # Notifies by email to the customer about a new order
        #
        # The email address is retrieved from the order
        #
        # It allows to define a custom template naming it as order_customer_req_notification
        #
        def notify_request_to_customer

          if send_notifications?
            unless customer_email.empty?

              bcn_template = ContentManagerSystem::Template.first(:name => 'order_customer_req_notification')

              if bcn_template
                template = ERB.new bcn_template.translate(customer_language).text
              else
                template = ERB.new ::Yito::Model::Order.customer_notification_booking_request_template
              end

              message = template.result(binding)

              Notifier.delay.notify_request_to_customer(self.customer_email,
                ::Yito::Model::Order.r18n(self.customer_language).t.notifications.customer_req_email_subject.to_s,
                message, self.id)

            end
          end

        end

        #
        # Notifies by email to the customer 
        #
        # The email address is retrieved from the order
        #
        # It allows to define a custom template naming it as order_customer_req_notification
        #
        def notify_request_to_customer_pay_now

          if send_notifications?
            unless customer_email.empty?

              bcn_template = ContentManagerSystem::Template.first(:name => 'order_customer_req_pay_now_notification')

              if bcn_template
                template = ERB.new bcn_template.translate(customer_language).text
              else
                template = ERB.new ::Yito::Model::Order.customer_notification_request_pay_now_template
              end

              message = template.result(binding)

              Notifier.delay.notify_request_to_customer_pay_now(self.customer_email,
                ::Yito::Model::Order.r18n(self.customer_language).t.notifications.customer_req_email_subject.to_s,
                message, self.id)

            end
          end

        end


        #
        # Notifies by email the customer the order confirmation
        # 
        # The email address is retrieved from the order
        #
        # It allows to define a custom template naming it as order_customer_notification
        # 
        #
        def notify_customer

          unless customer_email.empty?

            bcn_template = ContentManagerSystem::Template.first(:name => 'order_customer_notification')
        
            if bcn_template
              template = ERB.new bcn_template.translate(customer_language).text
            else
              template = ERB.new ::Yito::Model::Order.customer_notification_booking_confirmed_template
            end

            message = template.result(binding)

            Notifier.delay.notify_customer(self.customer_email, 
              ::Yito::Model::Order.r18n(self.customer_language).t.notifications.customer_email_subject.to_s,
              message, self.id)

          end

        end

        #
        # Notifies by email the customer that the payment has been enabled for the order
        #
        def notify_customer_payment_enabled

          unless customer_email.empty?

            bcn_template = ContentManagerSystem::Template.first(:name => 'order_customer_notification_payment_enabled')
        
            if bcn_template
              template = ERB.new bcn_template.translate(customer_language).text
            else
              template = ERB.new ::Yito::Model::Order.customer_notification_booking_confirmed_template
            end

            message = template.result(binding)

            Notifier.delay.notify_customer_payment_enabled(self.customer_email, 
              ::Yito::Model::Order.r18n(self.customer_language).t.notifications.customer_payment_enabled_subject.to_s,
              message, self.id)

          end


        end

        #
        # Check if the notifications should be send
        #
        def send_notifications?

          if created_by_manager
            notify = SystemConfiguration::Variable.get_value('booking.send_notifications_backoffice_reservations', 'false').to_bool
          else
            notify = SystemConfiguration::Variable.get_value('booking.send_notifications', 'true').to_bool
          end

        end
  
      end
    end
  end
end