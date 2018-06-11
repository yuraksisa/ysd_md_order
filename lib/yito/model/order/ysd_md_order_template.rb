module Yito
  module Model
    module Order
      module Templates
        def self.contract
          file = File.expand_path(File.join(File.dirname(__FILE__), "../../../..",
                                            "templates", "contract_pdf.erb"))
          File.read(file)
        end
      end
    end
  end
end