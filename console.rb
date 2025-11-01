require 'tty-prompt'
require 'tty-command'

# load env
require 'dotenv'
Dotenv.load

# load cache store
require './models/memory_cache/store'

# load app
require './webpay_admin'

# load SimpleRodaContext to emulate roda req/resp
require './models/simple_roda_context'

DB.loggers = [] # don't log sql

# import devices from tmp/devices.csv
def import_devices
  require 'csv'

  # model; code; serial
  CSV.foreach('tmp/devices.csv', headers: true, header_converters: :symbol, col_sep: ';') do |row|
    puts "Importing device: #{row}"
    Device.create product_model: row[:model], product_code: row[:code], serial_number: row[:serial], type: 'pos', status: 'idle'
  end

  rescue => e
    puts "Error: #{e.class}, #{e.message}"
end

@prompt = TTY::Prompt.new
@models = [Permission]

Permission.instance_eval {serializer file_name: "permissions.json"}

# @models.each do |m|
#   m.instance_eval {serializer file_name: "#{m.to_s.downcase}s.json"}
# end

def print_model_status(model)
  json_file = model.send(:load_from_file)

  db_count = model.send(:count)
  db_timestamp = model.order(:updated_at).send(:last).try(:created_at) || 'none'

  file_count = json_file[:data].size
  file_timestamp = json_file[:ctime]

  db_empty = db_count == 0

  if db_empty
    status = {type: :error, text: 'Table is empty!'} if db_empty
  else
    needs_update = file_timestamp > db_timestamp
    up_to_date = file_timestamp < db_timestamp
    status = {type: :warn, text: 'Needs update.'} if !db_empty and needs_update
    status = {type: :ok, text: 'Up to date.'} if !db_empty and up_to_date
  end

  if !db_empty
    @prompt.ok("#{model}s ✔")
  elsif
    @prompt.error("#{model}s ✗")
  end
  @prompt.ok("=> db count: #{db_count} | db timestamp: #{db_timestamp}")
  @prompt.ok("=> file count: #{file_count} | file timestamp: #{file_timestamp}")
  @prompt.send(status[:type], "Summary: #{status[:text]}")
end


def print_models_statuses
  @models.each do |m|
    print_model_status m
    puts
  end
end

def create_superuser
  if !Admin.count.zero?
    @prompt.warn 'Already created!'
  else
    first_name = @prompt.ask('First name?')
    last_name = @prompt.ask('Last name?')
    phone = @prompt.ask('Phone?')
    email = @prompt.ask('Email?')

    context = SimpleRodaContext.new first_name: first_name, last_name: last_name, phone: phone, email: email, superuser: true
    context.suppress_output = true

    CreateAdmin.call(context)

    # failed or success
    if !Admin.count.zero?
      @prompt.ok "Activation link is send to #{email}"
    else
      puts
      context.output.each { |k, v|  @prompt.error "#{k.to_s.split('_').join(' ').capitalize}: #{v[0]}"}
    end

  end
  puts
  menu
end

def exit_console
  @prompt.say 'Goodbye'
  puts
  exit
end

def run
  puts
  exit_console if @res == :exit
  confirm = @prompt.yes?('Please confirm action.')

  # model updates
  model = @res
  model.send(:save_to_db_from_file!, true) if model.respond_to?(:save_to_db_from_file!) and confirm

  # custom tasks
  create_superuser  if @res == :create_superuser and confirm
  import_devices    if @res == :import_devices #and confirm

  puts
  # print_models_statuses
  puts
  menu
end

def menu
  choices = @models.inject({}) {|a, model| a.update("Import #{model}s" => model)}
  choices.merge!(
    'Import devices' => :import_devices,
    'Create superuser account' => :create_superuser,
    'Exit console' => :exit
  )
  @res = @prompt.select("Choose task?", choices, per_page: 20)
  run
end

puts
print_models_statuses
puts
menu
