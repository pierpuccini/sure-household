class StatementCycle::Selection
  attr_reader :family, :accounts, :statement_month

  def initialize(family:, accounts:, statement_month:, enabled:)
    @family = family
    @accounts = Array(accounts).compact
    @statement_month = statement_month.to_date.beginning_of_month
    @enabled = ActiveModel::Type::Boolean.new.cast(enabled)
  end

  def enabled?
    @enabled
  end

  def display_mode
    enabled? ? :statement_cycles : :calendar_month
  end

  def calendar_period
    @calendar_period ||= Period.custom(
      start_date: statement_month.beginning_of_month,
      end_date: statement_month.end_of_month
    )
  end

  def envelope_period
    @envelope_period ||= begin
      periods = account_periods.values
      return calendar_period if periods.empty?

      Period.custom(
        start_date: periods.map(&:start_date).min,
        end_date: periods.map(&:end_date).max
      )
    end
  end

  def account_periods
    @account_periods ||= accounts.index_with { |account| period_for(account) }
  end

  def header_text
    return "Showing data from #{formatted_date(calendar_period.start_date)} to #{formatted_date(calendar_period.end_date)}" unless enabled?

    "Showing #{statement_month.strftime('%B %Y')} statement-cycle data"
  end

  def apply_to_scope(scope, account_column: "entries.account_id", date_column: "entries.date")
    grouped_account_ids = account_periods.group_by { |_account, period| [ period.start_date, period.end_date ] }
    return scope.where("#{date_column} BETWEEN ? AND ?", calendar_period.start_date, calendar_period.end_date) if grouped_account_ids.empty?

    clauses = []
    binds = []

    grouped_account_ids.each do |(start_date, end_date), account_pairs|
      account_ids = account_pairs.map { |(account, _period)| account.id }
      clauses << "(#{account_column} IN (?) AND #{date_column} BETWEEN ? AND ?)"
      binds << account_ids
      binds << start_date
      binds << end_date
    end

    scope.where([ clauses.join(" OR "), *binds ])
  end

  private
    def period_for(account)
      return calendar_period unless enabled?
      return calendar_period unless account.accountable_type == "CreditCard"
      return calendar_period unless account.accountable.statement_cycle_configured?

      # Rule 3: family-wide statement-cycle views are resolved per credit card.
      # Cards with statement settings use their own configured cycle for the selected
      # statement month, while cards without settings fall back to the calendar month.
      cycle = account.accountable.statement_cycle_for(statement_month)

      Period.custom(start_date: cycle.start_date, end_date: cycle.end_date)
    end

    def formatted_date(date)
      date.strftime("%b %-d, %Y")
    end
end
