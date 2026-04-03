class UI::Account::ActivityFeed < ApplicationComponent
  attr_reader :feed_data, :pagy, :search, :statuses, :selected_month, :use_statement_cycles

  def initialize(feed_data:, pagy:, search: nil, statuses: nil, selected_month: nil, use_statement_cycles: false)
    @feed_data = feed_data
    @pagy = pagy
    @search = search
    @statuses = Array(statuses).compact_blank
    @selected_month = selected_month
    @use_statement_cycles = ActiveModel::Type::Boolean.new.cast(use_statement_cycles)
  end

  def id
    dom_id(account, :activity_feed)
  end

  def broadcast_channel
    account
  end

  def broadcast_refresh!
    Turbo::StreamsChannel.broadcast_replace_to(
      broadcast_channel,
      target: id,
      renderable: self,
      layout: false
    )
  end

  def activity_dates
    feed_data.entries_by_date
  end

  def credit_card_filter_available?
    account.credit_card?
  end

  def selected_month_value
    selected_month&.strftime("%Y-%m")
  end

  def statement_cycles_checked?
    use_statement_cycles
  end

  def filters_active?
    search.present? || statuses.present? || selected_month.present? || use_statement_cycles
  end

  private
    def account
      feed_data.account
    end
end
