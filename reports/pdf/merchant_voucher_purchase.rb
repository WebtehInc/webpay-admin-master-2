module Reports
  class MerchantVoucherPurchase
    attr_accessor :pdf, :file_name, :data

    include Reports::PdfReportInstanceMethods
    extend  Reports::PdfReportClassMethods

    def initialize(type)
      @file_name  = "voucher-purchase-report-#{Time.now.strftime("%d-%m-%Y-%I_%M_%S_%p")}.pdf"
      @data = []

      accounts = Account.where(type: 'business')
      products = DB[:products].as_hash(:id) # {2=>{:id=>2, :name=>"Chippie 10", :price=>100

      accounts.each do |a|
        a.voucher_stocks_dataset.order(:name).each do |s|
          unit_price = products[s.product_id][:price]

          @data << {account:          a.account_number,
                    merchant:         a.merchant_name,
                    product:          s.name,
                    price:            integer_to_currency(unit_price),
                    stock_qty:        s.quantity,
                    purchased_qty:    s.last_purchase_quantity,
                    purchased_value:  integer_to_currency(unit_price * s.quantity),
                    purchased_at:     (s[:replenished_at].strftime("%d-%m-%Y, %I:%M:%S %p") rescue '-')}
        end
      end
    end

    def generate_pdf
      pdf.move_down 20
      pdf.text 'Merchant e-voucher stock & last purchase', :size => 18, :align => :left, style: :bold
      pdf.text "Generated at: #{Time.now.strftime("%d-%m-%Y, %I:%M:%S %p")}", :size => 14, :align => :left
      pdf.move_down 15

      header  = [['Account', 'Merchant', 'Product', 'Denom.', 'Stock qty.', 'Purch. qty.', 'Purch. value', 'Purch. time']]
      data = header + @data.reduce([]){|acc, item| acc << item.values}

      pdf.table(data, header: true, width: 540, cell_style: { size: 8, border_widths: [0.5, 0.5, 0.5, 0.5]}) do
        style(row(0), background_color: 'eeeeee', size: 10)
        style(column(3), align: :right)
        style(column(4), align: :right)
        style(column(5), align: :right)
        style(column(6), align: :right)
        style(column(7), align: :right)
      end
    end
  end
end
