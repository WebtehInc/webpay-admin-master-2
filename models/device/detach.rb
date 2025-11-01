class DetachDevice

  def self.call(id, context)
    device = Device[id]

    if device and (terminal = device.terminal)
      Device.update(id, context.admin_id, terminal_id: nil, removed_at: Time.now, status: 'idle')
      Terminal.update(terminal.id, context.admin_id, access_token: nil, terminal_key: nil)
      context.render_success
    else
      context.render_error(['cannot remove device'])
    end
  end

end
