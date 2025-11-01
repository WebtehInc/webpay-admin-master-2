require_relative "infoswitch_test_helper"

module InfoSwitch
  class TestTerminalApi < InfoSwitchTest

    # See InfoSwitch::InfoSwitchTest#setup for where @terminal is created

    def test_create_or_update
      rv = @terminal

      assert_equal 'updated', rv['status'], 'result is off'

      pos_tmk_under_master_tmk = rv['tmk']
      pos_tmk_kcv = rv['tmk_kcv']

      pos_tmk = m.decrypt_tmk pos_tmk_under_master_tmk
      assert_equal pos_tmk_kcv, m.calculate_kcv_hex(pos_tmk), "KCV for POS TMK is off after decryption"
    end

  end
end