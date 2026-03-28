class MonthlySummary
  OwnerTotal = Data.define(:owner, :amount)
  AccountTotal = Data.define(:account, :amount)
  CardCycleTotal = Data.define(:account, :cycle, :amount, :transactions)
  RecurringStatus = Data.define(:recurring_transaction, :paid)

  attr_reader :family, :month

  def initialize(family:, month:)
    @family = family
    @month = month.to_date.beginning_of_month
  end

  def period
    @period ||= Period.custom(start_date: month.beginning_of_month, end_date: month.end_of_month)
  end

  def transactions
    @transactions ||= family.transactions
      .visible
      .merge(Entry.excluding_split_parents)
      .includes({ entry: :account }, :category, :merchant, :tags)
      .where(entries: { date: period.date_range })
      .to_a
  end

  def owner_totals
    Transaction.owners.keys.map do |owner|
      OwnerTotal.new(
        owner: owner,
        amount: transactions.select { |transaction| transaction.owner == owner }.sum { |transaction| transaction.entry.amount.to_d }
      )
    end
  end

  def account_totals
    family.accounts.visible.map do |account|
      amount = transactions.select { |transaction| transaction.entry.account_id == account.id }.sum { |transaction| transaction.entry.amount.to_d }
      AccountTotal.new(account: account, amount: amount)
    end.reject { |row| row.amount.zero? }
  end

  def credit_card_cycles
    family.accounts.visible.select { |account| account.accountable_type == "CreditCard" }.map do |account|
      cycle = account.accountable.statement_cycle_for(month)
      card_transactions = account.transactions
        .visible
        .includes(:category, :merchant, :tags, :entry)
        .where(entries: { date: cycle.start_date..cycle.end_date })
        .to_a

      amount = card_transactions.sum { |transaction| transaction.entry.amount.to_d }
      CardCycleTotal.new(
        account: account,
        cycle: cycle,
        amount: amount,
        transactions: card_transactions
      )
    end
  end

  def recurring_statuses
    family.recurring_transactions.active.map do |recurring_transaction|
      paid = recurring_transaction.matching_transactions.any? { |entry| period.date_range.cover?(entry.date) }
      RecurringStatus.new(recurring_transaction: recurring_transaction, paid: paid)
    end
  end

  def income_total
    family.income_statement.income_totals(period: period).total
  end

  def expense_total
    family.income_statement.expense_totals(period: period).total
  end

  def net_total
    income_total - expense_total
  end

  def budget
    @budget ||= Budget.find_or_bootstrap(family, start_date: month)
  end
end
