class Event < Sequel::Model

  plugin :serialization, :json, :body, :params, :env

  PUBLIC_ATTRS = self.columns rescue []

end