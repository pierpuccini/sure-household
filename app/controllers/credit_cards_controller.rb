class CreditCardsController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes(
    :id,
    :available_credit,
    :minimum_payment,
    :apr,
    :annual_fee,
    :expiration_date,
    :statement_cutoff_mode,
    :statement_cutoff_day,
    :statement_cutoff_week_of_month,
    :statement_cutoff_weekday,
    :statement_custom_start_day,
    :statement_custom_end_day,
    :statement_includes_cutoff_day,
    :payment_due_mode,
    :payment_due_day,
    :payment_due_week_of_month,
    :payment_due_weekday
  )
end
