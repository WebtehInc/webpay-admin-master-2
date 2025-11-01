require 'dotenv'
Dotenv.load

require 'digest'

module SpaFilesUpdater
  extend self

  def update!
    puts 'Updating spa files ...'

    # index.html and index.html.example template in public
    html_index_path           = 'public/index.html'
    html_index_template_path  = 'public/index.html.example'

    # source path and file
    source_js_path            = 'spa'
    source_js_file_name       = 'main_js_file'

    # target js paths
    target_js_path            = 'public/static'
    target_js_archive_path    = 'public/static/archive'

    # constants to replace
    spa_js_file_placeholder   = 'SPA_JS_FILE_PLACEHOLDER'   # js src link in index.html
    spa_app_name_placeholder  = 'SPA_APP_NAME_PLACEHOLDER'  # title in index.html
    spa_domain_placeholder    = 'SPA_DOMAIN_PLACEHOLDER'    # in js file
    spa_default_country_placeholder = 'SPA_DEFAULT_COUNTRY_PLACEHOLDER' # in js file

    # new values for constants
    spa_domain                = ENV["WP_SPA_HOST_URL"].chomp('#!').to_s
    app_name                  = ENV["APP_NAME"].to_s
    default_country           = ENV["DEFAULT_COUNTRY"].to_s

    # update domain and app name placeholders with env values
    new_file_name_with_placeholder = Dir.entries(source_js_path).find{|name| name.start_with?(source_js_file_name)}
    updated_js = File.read("#{source_js_path}/#{new_file_name_with_placeholder}")
                     .gsub(spa_domain_placeholder, spa_domain)
                     .gsub(spa_app_name_placeholder, app_name)
                     .gsub(spa_default_country_placeholder, default_country)

    # create tmp file in spa folder
    new_file_name   = "main.#{Time.now.strftime("%d%m%Y-%I%M%S")}.js"
    new_file_path   = "#{source_js_path}/#{new_file_name}"
    File.open(new_file_path, 'w'){|file| file.puts updated_js}
    new_file_digest = Digest::SHA512.file(new_file_path).hexdigest

    # load existing file in public path
    existing_file_name    = Dir.entries(target_js_path).find{|name| name.start_with?('main')}
    existing_file_path    = "#{target_js_path}/#{existing_file_name}"
    existing_file_digest  = Digest::SHA512.file(existing_file_path).hexdigest rescue 'no existing file'

    # update if checksum is not the same
    if new_file_digest != existing_file_digest

      # copy new js file
      FileUtils.cp(new_file_path, "#{target_js_path}/#{new_file_name}")

      # archive existing js file in public
      FileUtils.mv(existing_file_path, "#{target_js_archive_path}/#{existing_file_name}") rescue 'no existing file'

      # update index.html with new js link and app name
      updated_html = File.read(html_index_template_path).gsub(spa_js_file_placeholder, new_file_name).gsub(spa_app_name_placeholder, app_name)
      File.open(html_index_path, 'w'){|file| file.puts updated_html}

      puts "Spa files updated in public path: #{new_file_path} => #{existing_file_path}"
      $SPA_FILE_NAME = new_file_name
    else
      $SPA_FILE_NAME = existing_file_name
      puts 'Spa files has not been changed.'
    end

    # delete tmp file in spa
    FileUtils.rm(new_file_path); false
  end
end
