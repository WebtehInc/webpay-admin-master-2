require 'rake/testtask'

# task default: :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/unit/**/test*.rb', 'test/integration/**/test*.rb']
  t.verbose = true
  t.warning = false
end

Rake::TestTask.new(:unit) do |t|
  t.test_files = FileList['test/unit/**/test*.rb']
  t.warning = false
end

Rake::TestTask.new(:integration) do |t|
  t.test_files = FileList['test/integration/**/test*.rb']
  t.warning = false
end

task :app do
  require './webpay_admin'
end

Dir[File.dirname(__FILE__) + "/lib/tasks/*.rb"].sort.each do |path|
  require path
end
