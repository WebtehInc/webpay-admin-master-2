require 'prawn'
require 'prawn/table'

module Reports
  module PdfReportClassMethods

    # generate new report with header and footer
    def generate_pdf
      start_time = Time.now
      report = self.new('pdf')
      report.pdf = Prawn::Document.new
      report.add_header
      report.generate_pdf
      report.add_footer
      puts "PDF render time: #{Time.now - start_time} sec"
      return report
    end
  end

  module PdfReportInstanceMethods

    # pdf header with logo
    def add_header
      pdf.image './public/static/logo.png', position: :left, width: 150
    end

    # pdf footer with pagination
    def add_footer
      pdf.page_count.times do |i|
        pdf.bounding_box([pdf.bounds.left, pdf.bounds.bottom], :width => pdf.bounds.width, :height => 30) do
          pdf.go_to_page i + 1  # get page
          pdf.move_down 5       # move below the document margin
          pdf.text "#{i + 1}/#{pdf.page_count}", :align => :right # write the page number
        end
      end
    end

    # currency formatter
    def integer_to_currency(i, currency = nil)
      sprintf("%.2f", i/100.0).gsub(/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
    end

    # duration formatter
    def seconds_to_duration total_seconds
      days    = (total_seconds / (60 * 60 * 24))
      hours   = (total_seconds / (60 * 60)) % 24
      minutes = (total_seconds / 60) % 60
      # seconds = total_seconds % 60
      "#{ days }d #{ hours }h #{ minutes }m"
    end

    # save to file
    def save_pdf(path)
      pdf.render_file(path)
    end

    # render from roda context
    def render_pdf(context)
      # NOTE: we build binary download with javascript so we dont need file headers
      # context.response.headers = {'Content-Type' => 'application/pdf', 'Content-Disposition' => "attachment; filename=#{@file_name}"}
      context.response.status = 200
      context.response.write @pdf.render
      context.request.halt
    end
  end
end

require_relative 'pdf/voucher_stock'
require_relative 'pdf/merchant_exposure'
require_relative 'pdf/merchant_voucher_purchase'
require_relative 'pdf/merchant_open_batch'
