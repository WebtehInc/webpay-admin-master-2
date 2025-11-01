namespace :db do
  desc "Deactivate inactive users after period of inactivity"
  task :deactivate_inactive_users => :environment do
    INACTIVE_DAYS = 89
    puts "Deactivating users if not active for #{INACTIVE_DAYS} days ..."

    [User, Admin].each do |model|
      model.select(:id, :email, :active, :last_login_at).where do
        (last_login_at <= Time.now - 3600 * 24 * INACTIVE_DAYS) & :active
      end.tap do |users|
        puts "No inactive #{model.to_s.downcase}s found" if users.count.zero?
      end.each do |user|
        puts msg = "Deactivating #{user.email} #{model.to_s.downcase}"
        user.update active: false
        user.add_audit_message(msg)
      end
    end
  end
end
