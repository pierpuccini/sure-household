module OwnerBreakdown
  OWNERS = %w[me partner shared].freeze
  LABELS = {
    "me" => "Me",
    "partner" => "Partner",
    "shared" => "Shared"
  }.freeze
  COLORS = {
    "me" => "#2563eb",
    "partner" => "#f97316",
    "shared" => "#7c3aed"
  }.freeze

  class << self
    def net_spending_by_owner(transactions:, family_currency:)
      totals = OWNERS.index_with { 0 }

      transactions.includes(:entry).find_each do |transaction|
        owner = transaction.owner.presence || "shared"
        converted_amount = Money.new(transaction.entry.amount.abs, transaction.entry.currency)
          .exchange_to(family_currency, fallback_rate: 1)
          .amount

        if transaction.entry.amount.positive?
          totals[owner] += converted_amount
        else
          totals[owner] -= converted_amount
        end
      end

      totals.transform_values { |amount| [ amount, 0 ].max }
    end
  end
end
