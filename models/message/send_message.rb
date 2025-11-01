class SendMessage < DStruct::DStruct

  attributes  strings: [:title, :body, :user_id]

  def self.call(message_id, context)
    input = new(context.params)
    input.add_validation_schema MyValidationSchema

    if input.valid?
      Message.create( title: input.title, body: input.body, parent_id: message_id,
                      user_id: input.user_id, admin_id: context.admin_id, sender: 'admin')
      context.render_success
    else
      context.render_error(input.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do
    key(:user_id) { filled?}
    key(:title)   { filled? & size?(3..40) }
    key(:body)    { filled? & size?(3..500) }
  end

end