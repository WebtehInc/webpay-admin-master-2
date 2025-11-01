WebPayAdmin.route 'users' do |r|
  r.get ':id/show' do |id|
    puts '=> getting user ...'
    user = User[id]
    { wallet_transactions:  {count: DB[:transactions].where(user_id: id).exclude(transaction_type: BANK_TRANSACTION_TYPES.keys.stringify).count}, # exclude bank types
      bank_transactions:    {count: DB[:transactions].where(user_id: id, transaction_type: BANK_TRANSACTION_TYPES.keys.stringify).count},
      accounts:             user.accounts,
      documents:            user.documents,
      cards:                {count: user.cards.count}}
  end
  r.post ':id/update' do |id|
    puts '=> updating user ...'
    UpdateUser.call(id, self)
  end
  r.post ':id/send-message' do |id|
    puts '=> replying to message ...'
    SendMessage.call(nil, self) # reuse message API, parent message is nil, user_id is in body
  end
  r.post ':id/email-qr-code' do |id|
    puts '=> sending qr code ...'
    Mailer.sendmail('/user/qr-code', User[id])
    {}
  end
  r.post ':id/add-bank-account' do |id|
    puts '=> adding bank account ...'
    AddBankAccount.call(id, self)
  end
  r.post ':id/logins' do |id|
    puts '=> getting user logins ...'
    LoginTrail.where(user_id: id).reverse(:id).limit(20).all
  end
  r.post ':page' do |page|
    puts '=> getting users ...'
    r.paginated_dataset(*User.paginate(page, params[:search])).all
  end
end

WebPayAdmin.route 'documents' do |r|
  r.post ':id/update' do |id|
    puts '=> updating document ...'
    d = Document.update(id, admin_id, params)
    Mailer.sendmail("/user/document_status", d.user, d)
    []
  end
  r.post ':page' do |page|
    puts '=> getting documents ...'
    r.paginated_dataset(*Document.paginate(page, params[:search])).
      to_json(include: {user: {only: User::PUBLIC_ATTRS}})
  end
end

WebPayAdmin.route 'messages' do |r|
  r.post ':id/reply' do |id|
    puts '=> replying to message ...'
    SendMessage.call(id, self)
  end
  r.post ':id/show' do |id|
    puts '=> reading message ...'
    [Message[id].update(read_by_admin: true)]
  end
  r.post ':page' do |page|
    puts '=> getting messages ...'
    r.paginated_dataset(*Message.paginate(page, params[:search])).
      to_json(include: {user: {only: [:id, :first_name, :last_name]}, admin: {only: [:id, :first_name, :last_name]}})
  end
end
