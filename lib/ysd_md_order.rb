require 'ysd_md_request_information_aspect'
require 'yito/model/order/ysd_md_product'
require 'yito/model/order/ysd_md_order_notification'
require 'yito/model/order/ysd_md_order'
require 'yito/model/order/ysd_md_order_item'
require 'yito/model/order/ysd_md_order_item_customer'
require 'yito/model/order/ysd_md_order_item_resource'
require 'yito/model/order/ysd_md_order_charge'
require 'yito/model/order/ysd_md_order_charge_observer'
require 'yito/model/order/ysd_md_request_information'
require 'yito/model/order/ysd_md_shopping_cart'
require 'yito/model/order/ysd_md_shopping_cart_item'
require 'yito/model/order/ysd_md_shopping_cart_item_customer'

module Yito
  module Model
  	module Order
      extend Yito::Translation::ModelR18

      def self.r18n
        check_r18n!(:orders_r18n, File.expand_path(File.join(File.dirname(__FILE__), '..', 'i18n')))
      end
    end
  end
end