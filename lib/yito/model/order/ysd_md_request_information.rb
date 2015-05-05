require 'data_mapper' unless defined?DataMapper::Resource
module Yito
  module Model
    module Order
      class RequestInformation
        	include DataMapper::Resource
        storage_names[:default] = 'orderds_request_informations' 

        property :creation_date, DateTime, :field => 'creation_date'  # The creation date
        property :source, String, :field => 'source', :length => 50   # Where does the booking come from

        property :customer_name, String, :field => 'customer_name', :required => true, :length => 40
        property :customer_surname, String, :field => 'customer_surname', :required => true, :length => 40
        property :customer_email, String, :field => 'customer_email', :required => true, :length => 40
        property :customer_phone, String, :field => 'customer_phone', :required => true, :length => 15 
        property :customer_mobile_phone, String, :field => 'customer_mobile_phone', :length => 15
        property :customer_language, String, :field => 'customer_language', :length => 3

        property :notes, Text

        #
        # Before create hook (initilize fields)
        #
        before :create do |request_information|
          request_information.creation_date = Time.now unless request_information.creation_date
        end

      end
    end
  end
end