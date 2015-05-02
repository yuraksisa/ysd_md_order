require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder
require 'aspects/ysd-plugins_applicable_model_aspect' unless defined?Plugins::ApplicableModelAspect

module Yito
  module Model
    module Order
      class Product
  	  	include DataMapper::Resource
        extend  Plugins::ApplicableModelAspect           # Extends the entity to allow apply aspects
        extend  Yito::Model::Finder

        storage_names[:default] = 'orderds_products'

        property :id, Serial
        property :name, String, :field => 'name', :length => 80
        property :short_description, String, :field => 'short_description', :length => 80
        property :description, Text, :field => 'description'

      end
    end
  end
end