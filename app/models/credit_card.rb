class CreditCard < ApplicationRecord
  include Accountable

  CYCLE_MODES = {
    "fixed_day" => "Fixed day of month",
    "nth_weekday" => "Nth weekday of month",
    "custom_range" => "Custom day window"
  }.freeze

  WEEKDAY_OPTIONS = Date::DAYNAMES.each_with_index.map { |day, index| [ day, index ] }.freeze
  WEEK_OF_MONTH_OPTIONS = [
    [ "First", 1 ],
    [ "Second", 2 ],
    [ "Third", 3 ],
    [ "Fourth", 4 ],
    [ "Last", 5 ]
  ].freeze

  SUBTYPES = {
    "credit_card" => { short: "Credit Card", long: "Credit Card" }
  }.freeze

  enum :statement_cutoff_mode, CYCLE_MODES.keys.index_with(&:to_s), validate: true, prefix: :statement_cutoff
  enum :payment_due_mode, CYCLE_MODES.except("custom_range").keys.index_with(&:to_s), validate: true, prefix: :payment_due

  validates :statement_cutoff_day, inclusion: { in: 1..31 }, if: :statement_cutoff_fixed_day?
  validates :payment_due_day, inclusion: { in: 1..31 }, if: :payment_due_fixed_day?
  validates :statement_cutoff_week_of_month, inclusion: { in: 1..5 }, if: :statement_cutoff_nth_weekday?
  validates :payment_due_week_of_month, inclusion: { in: 1..5 }, if: :payment_due_nth_weekday?
  validates :statement_cutoff_weekday, inclusion: { in: 0..6 }, if: :statement_cutoff_nth_weekday?
  validates :payment_due_weekday, inclusion: { in: 0..6 }, if: :payment_due_nth_weekday?
  validates :statement_custom_start_day, inclusion: { in: 1..31 }, if: :statement_cutoff_custom_range?
  validates :statement_custom_end_day, inclusion: { in: 1..31 }, if: :statement_cutoff_custom_range?

  class << self
    def color
      "#F13636"
    end

    def icon
      "credit-card"
    end

    def classification
      "liability"
    end
  end

  def available_credit_money
    available_credit ? Money.new(available_credit, account.currency) : nil
  end

  def minimum_payment_money
    minimum_payment ? Money.new(minimum_payment, account.currency) : nil
  end

  def annual_fee_money
    annual_fee ? Money.new(annual_fee, account.currency) : nil
  end

  def statement_cycle_for(date)
    CreditCard::CycleCalculator.new(self).statement_cycle_for(date)
  end
end
