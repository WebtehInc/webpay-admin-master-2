module Reports
  class VoucherStock
    attr_accessor :pdf, :file_name, :data

    include Reports::PdfReportInstanceMethods
    extend  Reports::PdfReportClassMethods

    def initialize(type)
      @file_name  = "voucher-stock-report-#{Time.now.strftime("%d-%m-%Y-%I_%M_%S_%p")}.pdf"
      @data = []

      Product.stock_statistics.each do |s|
        @data << {product:      s[:name],
                  price:        "#{integer_to_currency(s[:price])} #{s[:currency]}",
                  quantity:     s[:quantity],
                  total:        "#{integer_to_currency(s[:price] * s[:quantity])} #{s[:currency]}",
                  replenish_at: (s[:replenished_at].strftime("%d-%m-%Y, %I:%M:%S %p") rescue '-')}
      end
    end

    def generate_pdf
      pdf.move_down 20
      pdf.text 'E-voucher stock', :size => 18, :align => :left, style: :bold
      pdf.text "Generated at: #{Time.now.strftime("%d-%m-%Y, %I:%M:%S %p")}", :size => 14, :align => :left
      pdf.move_down 15

      header = [['Product', 'Denomination', 'Quantity', 'Quantity value', 'Replenished at']]
      data = header + @data.reduce([]){|acc, item| acc << item.values}

      pdf.table(data, header: true, width: 540, cell_style: { size: 8, border_widths: [0.5, 0.5, 0.5, 0.5]}) do
        style(row(0), background_color: 'eeeeee', size: 10)
        style(column(1), align: :right)
        style(column(2), align: :right)
        style(column(3), align: :right)
        style(column(4), align: :right)
      end
    end
  end
end
