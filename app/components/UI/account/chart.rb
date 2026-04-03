class UI::Account::Chart < ApplicationComponent
  attr_reader :account

  def initialize(account:, period: nil, view: nil, summary_trend: nil)
    @account = account
    @period = period
    @view = view
    @summary_trend = summary_trend
  end

  def period
    @period ||= Period.last_30_days
  end

  def holdings_value_money
    account.balance_money - account.cash_balance_money
  end

  def view_balance_money
    case view
    when "balance"
      account.balance_money
    when "holdings_balance"
      holdings_value_money
    when "cash_balance"
      account.cash_balance_money
    end
  end

  def title
    case account.accountable_type
    when "Investment", "Crypto"
      case view
      when "balance"
        "Total account value"
      when "holdings_balance"
        "Holdings value"
      when "cash_balance"
        "Cash value"
      end
    when "Property", "Vehicle"
      "Estimated #{account.accountable_type.humanize.downcase} value"
    when "CreditCard", "OtherLiability"
      "Debt balance"
    when "Loan"
      "Remaining principal balance"
    else
      "Balance"
    end
  end

  def foreign_currency?
    account.currency != account.family.currency
  end

  def converted_balance_money
    return nil unless foreign_currency?

    account.balance_money.exchange_to(account.family.currency, fallback_rate: 1)
  end

  def view
    @view ||= "balance"
  end

  def series
    account.balance_series(period: period, view: view)
  end

  def trend
    return @summary_trend if @summary_trend.present?

    first_point = series.values.first
    last_point = series.values.last
    opening_balance = first_point&.trend&.previous

    return series.trend if first_point.nil? || last_point.nil? || opening_balance.nil?

    Trend.new(
      current: last_point.value,
      previous: opening_balance,
      favorable_direction: series.favorable_direction
    )
  end

  def custom_period?
    period.key.blank?
  end

  def selected_period_key
    period.key
  end
end
