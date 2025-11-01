class UpdateRole < DStruct::DStruct

  attributes strings: [:name, :description]

  def self.call(id, context)

    update_role = new(context.params)
    update_role.add_validation_schema MyValidationSchema

    if update_role.valid?
      context.render_success if Role.update(id, context.admin_id, update_role.to_h)
    else
      context.render_error(update_role.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    key(:name)        { filled? & size?(3..40) }
    key(:description) { filled? & size?(3..200) }
  end

end