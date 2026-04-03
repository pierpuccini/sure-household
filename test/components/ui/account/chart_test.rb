require "test_helper"

class UI::Account::ChartTest < ActiveSupport::TestCase
  test "trend uses opening balance of the first day in the period" do
    component = UI::Account::Chart.new(account: accounts(:credit_card))
    series = Series.new(
      start_date: Date.new(2026, 1, 1),
      end_date: Date.new(2026, 1, 2),
      interval: "1 day",
      favorable_direction: "down",
      values: [
        Series::Value.new(
          date: Date.new(2026, 1, 1),
          date_formatted: "January 1, 2026",
          value: Money.new(130_00, "USD"),
          trend: Trend.new(
            current: Money.new(130_00, "USD"),
            previous: Money.new(100_00, "USD"),
            favorable_direction: "down"
          )
        ),
        Series::Value.new(
          date: Date.new(2026, 1, 2),
          date_formatted: "January 2, 2026",
          value: Money.new(150_00, "USD"),
          trend: Trend.new(
            current: Money.new(150_00, "USD"),
            previous: Money.new(130_00, "USD"),
            favorable_direction: "down"
          )
        )
      ]
    )

    component.stubs(:series).returns(series)

    assert_equal Money.new(50_00, "USD"), component.trend.value
    assert_equal 50.0, component.trend.percent
  end
end
