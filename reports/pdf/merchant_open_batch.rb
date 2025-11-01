module Reports
  class MerchantOpenBatch
    attr_accessor :pdf, :file_name, :data

    include Reports::PdfReportInstanceMethods
    extend  Reports::PdfReportClassMethods

    def initialize(type)
      @file_name  = "open-batch-report-#{Time.now.strftime("%d-%m-%Y-%I_%M_%S_%p")}.pdf"
      @data = []

      Terminal.order(:services_batch_start_date).each do |t|

        # totals
        sales = Transaction.where(terminal_id: t.id, services_batch_number: t.services_batch_number, voided: false).sum(:amount).to_i # sum is nil for empty batch
        voids = Transaction.where(terminal_id: t.id, services_batch_number: t.services_batch_number, voided: true).sum(:amount).to_i
        total = sales - voids

        # how old is the batch ?
        duration_in_seconds  = (Time.now - t.services_batch_start_date).to_i

        @data << {merchant:    "#{t.merchant_name}, #{t.merchant_address}",
                  terminal_id: t.id,
                  sales:       integer_to_currency(sales),
                  voids:       integer_to_currency(voids),
                  total:       integer_to_currency(total),
                  duration:    seconds_to_duration(duration_in_seconds)}
      end
    end

    def generate_pdf
      pdf.move_down 20
      pdf.text 'No lodgments - totals from current batch', :size => 18, :align => :left, style: :bold
      pdf.text "Generated at: #{Time.now.strftime("%d-%m-%Y, %I:%M:%S %p")}", :size => 14, :align => :left
      pdf.move_down 15

      header = [['Merchant', 'Terminal', 'Sales', 'Refunds', 'Total amount', 'Days']]
      data = header + @data.reduce([]){|acc, item| acc << item.values}

      pdf.table(data, header: true, width: 540, cell_style: { size: 8, border_widths: [0.5, 0.5, 0.5, 0.5]}) do
        style(row(0), background_color: 'eeeeee', size: 10)
        style(column(1), align: :right)
        style(column(2), align: :right)
        style(column(3), align: :right)
        style(column(4), align: :right)
        style(column(5), align: :right)
        style(column(6), align: :right)
        style(column(7), align: :right)
      end
    end
  end
end
