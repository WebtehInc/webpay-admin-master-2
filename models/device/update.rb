class UpdateDevice < DStruct::DStruct

  attributes  strings:  [:failure_type, :comment, :status]

  def self.call(id, context)

    update_device = new(context.params.except(:id))

    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
      end

      key(:failure_type)  { empty? | inclusion?(POS_DEVICE_FAILURES) }
      key(:comment)       { empty? | size?(5..500) }
      key(:status)        { filled? & inclusion?(%w(idle failure)) }
    end

    update_device.add_validation_schema validation_schema

    if update_device.valid?
      context.render_success if Device.update(id, context.admin_id, update_device.to_h.merge(type: 'pos'))
    else
      context.render_error(update_device.errors)
    end
  end

end
