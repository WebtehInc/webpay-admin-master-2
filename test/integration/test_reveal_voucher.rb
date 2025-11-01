require_relative "integration_helper"

class TestRevealVoucher < Test

  def test_reveal_voucher
    admin = create_admin
    login_admin
    authorize_with_otp

    terminal = generate_terminal

    generate_operator
    voucher1 = generate_voucher
    voucher2 = generate_voucher
    voucher3 = generate_voucher uid: 12345678

    Voucher.dataset.update(terminal_id: terminal.id, status: 'sold')
    trx = generate_transaction(voucher_id: voucher3.id, terminal_id:  terminal.id, transaction_type: 'voucher_mpos')

    post "/terminals/#{terminal.id}/reveal-voucher/#{trx.id}", {}.to_json
    assert last_response.ok?

    # assert_equal voucher3.decrypted_sensitive_data[:value], JSON.parse(last_response.body)['decrypted_value']
    resp = JSON.parse(last_response.body)
    assert_equal voucher3.uid, resp['uid']
    assert_equal voucher3.decrypted_sensitive_data[:value], resp['pin']

    # check values
    assert voucher3.reload.revealed
    assert_equal 1, admin.revealed_vouchers.count
  end
end
