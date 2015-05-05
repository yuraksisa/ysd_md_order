require 'yito/model/order/ysd_md_product'
require 'yito/model/order/ysd_md_order'
require 'yito/model/order/ysd_md_order_item'
require 'yito/model/order/ysd_md_order_charge'
require 'yito/model/order/ysd_md_order_charge_observer'
require 'yito/model/order/ysd_md_request_information'

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