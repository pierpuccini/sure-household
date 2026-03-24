class MonthlySummariesController < ApplicationController
  def show
    @month = parse_month(params[:month])
    @summary = MonthlySummary.new(family: Current.family, month: @month)
    @breadcrumbs = [ [ "Home", root_path ], [ "Monthly Summary", nil ] ]
  end

  private
    def parse_month(value)
      return Date.current.beginning_of_month if value.blank?

      Date.strptime(value, "%Y-%m").beginning_of_month
    rescue Date::Error
      Date.current.beginning_of_month
    end
end
