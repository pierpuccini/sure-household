require "test_helper"

class Account::FilteredBalanceSummaryTest < ActiveSupport::TestCase
  include EntriesTestHelper

  test "calculates filtered end balances for asset accounts from the opening balance" do
    account = families(:empty).accounts.create!(
      name: "Filtered Checking",
      accountable: Depository.new,
      currency: "USD",
      balance: 0
    )

    first_date = Date.new(2026, 1, 5)
    create_transaction(account: account, date: first_date, amount: 1_200, owner: "partner")
    create_transaction(account: account, date: first_date + 1.day, amount: 800, owner: "partner")

    summary = Account::FilteredBalanceSummary.new(
      account: account,
      entries: account.entries.order(:date),
      opening_balance_money: Money.new(10_000, "USD")
    )

    assert_equal Money.new(8_800, "USD"), summary.end_balances_by_date[first_date]
    assert_equal Money.new(8_000, "USD"), summary.end_balances_by_date[first_date + 1.day]
    assert_equal Money.new(-2_000, "USD"), summary.trend.value
    assert_equal(-20.0, summary.trend.percent)
  end

  test "calculates filtered end balances for liability accounts from the opening balance" do
    account = families(:empty).accounts.create!(
      name: "Filtered Card",
      accountable: CreditCard.new,
      currency: "USD",
      balance: 0
    )

    first_date = Date.new(2026, 1, 5)
    create_transaction(account: account, date: first_date, amount: 2_000, owner: "partner")
    create_transaction(account: account, date: first_date + 1.day, amount: -500, owner: "partner")

    summary = Account::FilteredBalanceSummary.new(
      account: account,
      entries: account.entries.order(:date),
      opening_balance_money: Money.new(10_000, "USD")
    )

    assert_equal Money.new(12_000, "USD"), summary.end_balances_by_date[first_date]
    assert_equal Money.new(11_500, "USD"), summary.end_balances_by_date[first_date + 1.day]
    assert_equal Money.new(1_500, "USD"), summary.trend.value
    assert_equal 15.0, summary.trend.percent
  end
end
