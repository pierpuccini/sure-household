class Account::FilteredBalanceSummary
  attr_reader :account, :entries

  def initialize(account:, entries:, opening_balance_money: nil)
    @account = account
    @entries = Array(entries).sort_by(&:date)
    @opening_balance_money = opening_balance_money
  end

  def end_balances_by_date
    @end_balances_by_date ||= begin
      running_balance = opening_balance_money

      entries.group_by(&:date).each_with_object({}) do |(date, date_entries), balances|
        running_balance += signed_entry_flows(date_entries)
        balances[date] = running_balance
      end
    end
  end

  def trend
    final_balance = end_balances_by_date.values.last
    return nil unless final_balance

    Trend.new(
      current: final_balance,
      previous: opening_balance_money,
      favorable_direction: account.favorable_direction
    )
  end

  private
    def opening_balance_money
      @opening_balance_money ||= begin
        first_entry_date = entries.first&.date
        return Money.new(0, account.currency) unless first_entry_date

        starting_balance = account.balances
          .where(currency: account.currency)
          .where("date <= ?", first_entry_date)
          .order(date: :desc)
          .first

        return Money.new(0, account.currency) unless starting_balance

        if starting_balance.date == first_entry_date
          starting_balance.start_balance_money
        else
          starting_balance.end_balance_money
        end
      end
    end

    def signed_entry_flows(date_entries)
      entry_flows = date_entries.sum(&:amount)
      account.asset? ? -entry_flows : entry_flows
    end
end
