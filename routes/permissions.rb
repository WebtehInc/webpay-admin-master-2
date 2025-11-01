WebPayAdmin.route 'admins' do |r|
  r.post 'create' do
    puts '=> creating admin ...'
    CreateAdmin.call(self)
  end
  r.post ':token/activate-account' do
    puts '=> activating account ...'
    ActivateAccount.call(self)
  end
  r.post ':id/update' do |id|
    puts '=> updating admin ...'
    UpdateAdmin.call(id, self)
  end
  r.post ':id/email-qr-code' do |id|
    puts '=> sending qr code ...'
    Mailer.sendmail('/admin/qr-code', Admin[id])
    {}
  end
  r.get do
    puts '=> getting all admins ...'
    Admin.where(superuser: false).all
  end
  r.post ':page' do |page|
    puts '=> getting admins ...'
    r.paginated_dataset(*Admin.paginate(page, params[:search])).to_json(include:
    {roles: {only: [:id, :name]}, permissions: {only: [:id, :context, :action]}})
  end
end

WebPayAdmin.route 'roles' do |r|
  r.post 'create' do |id|
    puts '=> creating role ...'
    CreateRole.call(self)
  end
  r.post ':id/update' do |id|
    puts '=> updating role ...'
    UpdateRole.call(id, self)
  end
  r.post ':id/delete' do |id|
    puts '=> deleting role ...'
    [Role[id].delete] rescue nil
  end
  r.post ':id/add-permission/:p_id' do |id, p_id|
    puts '=> adding permission to role ...'
    [Role[id].add_permission(Permission[p_id])] rescue nil
  end
  r.post ':id/remove-permission/:p_id' do |id, p_id|
    puts '=> removing permission from role ...'
    [Role[id].remove_permission(Permission[p_id])]  rescue nil
  end
  r.post ':id/add-admin/:a_id' do |id, a_id|
    puts '=> adding admin to role ...'
    [Role[id].add_admin(Admin[a_id])] rescue nil
  end
  r.post ':id/remove-admin/:a_id' do |id, a_id|
    puts '=> removing admin from role ...'
    [Role[id].remove_admin(Admin[a_id])] rescue nil
  end
  r.get do
    puts '=> getting roles ...'
    Role.to_json(include: {permissions: {only: [:id, :context, :action]}, admins: {only: [:id, :first_name, :last_name]}})
  end
end

WebPayAdmin.route 'permissions' do |r|
  r.get do
    puts '=> getting permissions ...'
    Permission.dataset.order(:context).to_hash_groups(:context)
  end
end
