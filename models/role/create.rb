class CreateRole < DStruct::DStruct

  attributes strings: [:name, :description]

  def self.call(context)

    create_role = new(context.params)
    create_role.add_validation_schema MyValidationSchema

    if create_role.valid?
      context.render_success if Role.create(create_role.to_h.merge(admin_id: context.admin_id))
    else
      context.render_error(create_role.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do
    key(:name)        { filled? & size?(3..40) }
    key(:description) { filled? & size?(3..200) }
  end

end