require "test_helper"

class CreditCardCycleCalculatorTest < ActiveSupport::TestCase
  test "calculates fixed-day statement window excluding cutoff day" do
    cycle = credit_cards(:one).tap do |credit_card|
      credit_card.update!(
        statement_cutoff_mode: "fixed_day",
        statement_cutoff_day: 15,
        statement_includes_cutoff_day: false
      )
    end.statement_cycle_for(Date.new(2026, 1, 1))

    assert_equal Date.new(2025, 12, 15), cycle.start_date
    assert_equal Date.new(2026, 1, 14), cycle.end_date
  end

  test "calculates fixed-day statement window including cutoff day" do
    cycle = credit_cards(:one).tap do |credit_card|
      credit_card.update!(
        statement_cutoff_mode: "fixed_day",
        statement_cutoff_day: 15,
        statement_includes_cutoff_day: true
      )
    end.statement_cycle_for(Date.new(2026, 1, 1))

    assert_equal Date.new(2025, 12, 15), cycle.start_date
    assert_equal Date.new(2026, 1, 15), cycle.end_date
  end

  test "calculates nth-weekday statement window" do
    cycle = credit_cards(:one).tap do |credit_card|
      credit_card.update!(
        statement_cutoff_mode: "nth_weekday",
        statement_cutoff_week_of_month: 3,
        statement_cutoff_weekday: 5,
        statement_includes_cutoff_day: false
      )
    end.statement_cycle_for(Date.new(2026, 1, 1))

    assert_equal Date.new(2025, 12, 19), cycle.start_date
    assert_equal Date.new(2026, 1, 15), cycle.end_date
  end

  test "calculates custom day-window statement cycle" do
    cycle = credit_cards(:one).tap do |credit_card|
      credit_card.update!(
        statement_cutoff_mode: "custom_range",
        statement_custom_start_day: 27,
        statement_custom_end_day: 30,
        statement_includes_cutoff_day: true
      )
    end.statement_cycle_for(Date.new(2026, 1, 1))

    assert_equal Date.new(2025, 12, 27), cycle.start_date
    assert_equal Date.new(2026, 1, 30), cycle.end_date
  end
end
