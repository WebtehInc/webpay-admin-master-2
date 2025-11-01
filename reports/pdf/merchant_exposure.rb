module Reports
  class MerchantExposure
    attr_accessor :pdf, :file_name, :data

    include Reports::PdfReportInstanceMethods
    extend  Reports::PdfReportClassMethods

    def initialize(type)
      @file_name  = "exposure-report-#{Time.now.strftime("%d-%m-%Y-%I_%M_%S_%p")}.pdf"
      @data = []

      Account.order(:merchant_name).where(type: 'business').each do |a|
        new_exposure = a.previous_exposure_amount - a.last_exposure_amount_deposit
        @data << {account:        a.account_number,
                  merchant:       a.merchant_name,
                  prev_exposure:  integer_to_currency(a.previous_exposure_amount),
                  deposit:        integer_to_currency(a.last_exposure_amount_deposit),
                  exposure:       integer_to_currency(new_exposure.zero? ?  a.exposure_amount : new_exposure),
                  credit_limit:   integer_to_currency(a.credit_limit)}
      end
    end

    def generate_pdf
      pdf.move_down 20
      pdf.text 'Merchant credit limit & exposure', :size => 18, :align => :left, style: :bold
      pdf.text "Generated at: #{Time.now.strftime("%d-%m-%Y, %I:%M:%S %p")}", :size => 14, :align => :left
      pdf.move_down 15

      header = [['Account', 'Merchant', 'Prev. exposure', 'Deposit', 'Exposure', 'Credit limit']]
      data = header + @data.reduce([]){|acc, item| acc << item.values}

      pdf.table(data, header: true, width: 540, cell_style: { size: 8, border_widths: [0.5, 0.5, 0.5, 0.5]}) do
        style(row(0), background_color: 'eeeeee', size: 10)
        style(column(2), align: :right)
        style(column(3), align: :right)
        style(column(4), align: :right)
        style(column(5), align: :right)
      end
    end
  end
end
