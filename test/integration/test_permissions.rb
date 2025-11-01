require_relative "integration_helper"

class TestPermissions < Test

  # RBAC routes - 405
  def test_permission_to_reveal_sold_voucher

    superuser = create_admin
    login_admin superuser
    authorize_with_otp

    terminal = generate_terminal

    # sell one voucher
    generate_operator
    voucher = generate_voucher
    Voucher.dataset.update(terminal_id: terminal.id, status: 'sold')
    trx = generate_transaction(voucher_id: voucher.id, terminal_id:  terminal.id, transaction_type: 'voucher_mpos')

    # superuser can reveal voucher
    ok? 'post',  "/terminals/#{terminal.id}/reveal-voucher/#{trx.id}", {}.to_json
    post '/logout'

    # demote superuser
    operator = superuser.update superuser: false

    login_admin
    authorize_with_otp

    # admin without permission can't reveal voucher
    post "/terminals/#{terminal.id}/reveal-voucher/#{trx.id}", {}.to_json
    assert last_response.method_not_allowed? # 405

    # add permission to list
    role = Role.create(name: 'Terminal operator', description: '...')
    permission = Permission.create(context: 'terminals', action: 'list')
    role.add_admin operator
    role.add_permission permission

    # user can see terminal list now
    post  "/terminals/1", {}.to_json
    assert last_response.ok?

    # but he cant reveal the voucher yet
    not_allowed? 'post',  "/terminals/#{terminal.id}/reveal-voucher/#{trx.id}", {}.to_json

    # add permission to see it
    permission = Permission.create(context: 'terminals', action: 'reveal-voucher/#{trx.id}')
    role.add_permission permission

    # its can be revealed now
    post "/terminals/#{terminal.id}/reveal-voucher/#{trx.id}", {}.to_json
    last_response.ok?
  end

end
