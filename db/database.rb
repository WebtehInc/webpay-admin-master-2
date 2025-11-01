Sequel::Model.plugin :json_serializer
Sequel::Model.plugin :timestamps, update_on_create: true
Sequel::Model.plugin :tactical_eager_loading
Sequel.split_symbols = true # SEQUEL DEPRECATION WARNING: Symbol splitting is deprecated and will be removed in Sequel 5.  Either set Sequel.split_symbols = true or make changes

require "philtre"
require_relative "serializer"

# allow nil to be passed to as filter value
module Philtre
  class Filter
    def valued_parameters
      filter_parameters.select do |key, value|
        key.to_sym != :order && (value.is_a?(Array) || value != "")
      end
    end
  end
end

class Sequel::Model
  PER_PAGE = 25

  # finders for single row
  def self.find_value_by_attrs(value, attrs)
    where(attrs).get(value)
  end

  def self.find_values_by_attrs(values, attrs)
    where(attrs).select(*values).first
  end

  def self.find_all_values_by_attrs(attrs)
    where(attrs).first
  end

  # pagination with total count
  def self.paginate(current_page = 1, criteria = {}, ds = nil)

    # pass in dataset for non simple selects, like counts
    if ds
      count = Philtre.new(criteria).apply(ds).count
      dataset = ds.
        limit((self::PER_PAGE rescue PER_PAGE)).
        offset((self::PER_PAGE rescue PER_PAGE) * (current_page.to_i - 1))
    else
      count = Philtre.new(criteria).apply(self.dataset).count
      dataset = reverse(:id).
        select(*(self::PUBLIC_ATTRS rescue self.columns)).
        limit((self::PER_PAGE rescue PER_PAGE)).
        offset((self::PER_PAGE rescue PER_PAGE) * (current_page.to_i - 1))
    end

    filtered_dataset = Philtre.new(criteria).apply(dataset)

    [(self::PER_PAGE rescue PER_PAGE),
     count,
     filtered_dataset]
  end

  # update instance with audit, admin_id is changing the record
  def self.update(id, admin_id = nil, attrs = {})
    instance = self[id]
    if instance.update(attrs)
      instance.audit(admin_id)
      puts "=> updating #{instance.class} #{instance.id}..."
    end
    instance
  end

  # update instance with audit, admin_id is changing the record
  def self.create_with_audit(admin_id = nil, attrs = {})
    instance = self.new(attrs)
    if instance.save
      instance.audit(admin_id, attrs)
      puts "=> creating #{instance.class} #{instance.id}..."
    end
    instance
  end

  def audit(admin_id, changes = nil)
    puts "=> auditing #{self.class}: #{self.id} ..."
    changes = changes || previous_changes
    add_audit(model_name: model.name,
              admin_id: admin_id,
              diff: changes.reject { |k, v| [:created_at, :updated_at].include?(k) })
  end

  def add_audit_message(admin_id = nil, msg)
    add_audit model_name: model.name, admin_id: admin_id, diff: { "System message" => ["", msg] }
  end
end
