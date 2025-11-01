module Importers
  module QuickBookHelpers


    def build_operator_name stat
      # Entiero Na Kuota
      if stat[:code] == 'en'
        'ENK'

        # Paga Bo But
      elsif stat[:code] == 'pb'
        'PBB'

        # DigiCell Postpaid
      elsif stat[:code] == 'dp'
        'DGA'

      else
        stat[:name]

      end
    end


  end
end
