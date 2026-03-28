class CreditCard::CycleCalculator
  Result = Data.define(:statement_month, :start_date, :end_date, :cutoff_date)

  def initialize(credit_card)
    @credit_card = credit_card
  end

  def statement_cycle_for(date)
    statement_month = date.to_date.beginning_of_month
    current_cutoff = cutoff_date_for(statement_month)
    start_date = start_date_for(statement_month)

    Result.new(
      statement_month: statement_month,
      start_date: start_date,
      end_date: current_cutoff + inclusive_end_offset,
      cutoff_date: current_cutoff
    )
  end

  private
    attr_reader :credit_card

    def cutoff_date_for(month_date)
      case credit_card.statement_cutoff_mode
      when "fixed_day"
        day_based_date(month_date.year, month_date.month, credit_card.statement_cutoff_day)
      when "nth_weekday"
        nth_weekday_date(
          month_date.year,
          month_date.month,
          credit_card.statement_cutoff_week_of_month,
          credit_card.statement_cutoff_weekday
        )
      when "custom_range"
        day_based_date(month_date.year, month_date.month, credit_card.statement_custom_end_day)
      else
        raise ArgumentError, "Unsupported statement cutoff mode: #{credit_card.statement_cutoff_mode.inspect}"
      end
    end

    def start_date_for(statement_month)
      case credit_card.statement_cutoff_mode
      when "custom_range"
        previous_month = statement_month.prev_month
        day_based_date(previous_month.year, previous_month.month, credit_card.statement_custom_start_day)
      else
        cutoff_date_for(statement_month.prev_month)
      end
    end

    def day_based_date(year, month, day)
      date = Date.new(year, month, 1)
      safe_day = [[day.to_i, 1].max, date.end_of_month.day].min
      Date.new(year, month, safe_day)
    end

    def nth_weekday_date(year, month, week_of_month, weekday)
      first_day = Date.new(year, month, 1)
      offset = (weekday.to_i - first_day.wday) % 7
      first_occurrence = first_day + offset.days
      candidate = first_occurrence + (week_of_month.to_i - 1).weeks

      return candidate if candidate.month == month

      candidate - 1.week
    end

    def inclusive_end_offset
      credit_card.statement_includes_cutoff_day? ? 0.days : -1.day
    end
end
