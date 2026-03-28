require "test_helper"

class StatementCycle::SelectionTest < ActiveSupport::TestCase
  test "resolves statement cycles per credit card and uses calendar month for other accounts" do
    credit_card = credit_cards(:one)
    credit_card.update!(
      statement_cutoff_mode: "fixed_day",
      statement_cutoff_day: 15,
      statement_includes_cutoff_day: true
    )

    selection = StatementCycle::Selection.new(
      family: families(:dylan_family),
      accounts: [ accounts(:credit_card), accounts(:depository) ],
      statement_month: Date.new(2026, 3, 1),
      enabled: true
    )

    assert_equal Date.new(2026, 2, 15), selection.account_periods[accounts(:credit_card)].start_date
    assert_equal Date.new(2026, 3, 15), selection.account_periods[accounts(:credit_card)].end_date
    assert_equal Date.new(2026, 3, 1), selection.account_periods[accounts(:depository)].start_date
    assert_equal Date.new(2026, 3, 31), selection.account_periods[accounts(:depository)].end_date
    assert_equal Date.new(2026, 2, 15), selection.envelope_period.start_date
    assert_equal Date.new(2026, 3, 31), selection.envelope_period.end_date
    assert_equal "Showing March 2026 statement-cycle data", selection.header_text
  end

  test "falls back to the calendar month when statement cycles are disabled" do
    selection = StatementCycle::Selection.new(
      family: families(:dylan_family),
      accounts: [ accounts(:credit_card) ],
      statement_month: Date.new(2026, 3, 1),
      enabled: false
    )

    assert_equal :calendar_month, selection.display_mode
    assert_equal Date.new(2026, 3, 1), selection.account_periods[accounts(:credit_card)].start_date
    assert_equal Date.new(2026, 3, 31), selection.account_periods[accounts(:credit_card)].end_date
  end
end
