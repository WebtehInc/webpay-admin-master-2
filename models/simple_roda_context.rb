# mock for roda request/response context if using DStruct classes directly (outside the roda router)
class SimpleRodaContext
  attr_accessor :params, :output, :suppress_output

  def initialize params
    @params = params
  end

  def render_error errors
    @output = errors
    puts errors.inspect unless suppress_output
  end

  def render_success success
    @output = success
    puts success.inspect unless suppress_output
  end
end
