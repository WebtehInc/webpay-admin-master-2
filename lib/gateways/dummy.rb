class DummyGateway

  def authorize(input_hash)

    if input_hash[:amount] == 10000
      return {
        approval_code: '',
        reference_number: '',
        response_code: '05',
        response_message: 'not enough funds',
        status: 'declined'
      }
    else
      {
        approval_code: '123ABC',
        reference_number: '00001234',
        response_code: '00',
        response_message: 'transaction approved',
        status: 'approved'
      }
    end

  end

end