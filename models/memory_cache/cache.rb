module MemoryCache

  def self.fetch_setting(name)
    # return from memory
    form_cache = MEMORY_STORE.get(name)
    return form_cache if form_cache

    # load from db and write to memory
    setting = Setting.where(name: name).first
    MEMORY_STORE.set(setting[:name], setting.value)
    return setting.value
  end

end
