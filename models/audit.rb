class Audit < Sequel::Model

  plugin :serialization, :json, :diff

end