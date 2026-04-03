class UI::AccountPage < ApplicationComponent
  attr_reader :account, :chart_view, :chart_period, :chart_summary_trend

  renders_one :activity_feed, lambda { |feed_data:, pagy:, search:, statuses:, selected_month:, use_statement_cycles:|
    UI::Account::ActivityFeed.new(
      feed_data: feed_data,
      pagy: pagy,
      search: search,
      statuses: statuses,
      selected_month: selected_month,
      use_statement_cycles: use_statement_cycles
    )
  }

  def initialize(account:, chart_view: nil, chart_period: nil, chart_summary_trend: nil, active_tab: nil)
    @account = account
    @chart_view = chart_view
    @chart_period = chart_period
    @chart_summary_trend = chart_summary_trend
    @active_tab = active_tab
  end

  def id
    dom_id(account, :container)
  end

  def broadcast_channel
    account
  end

  def broadcast_refresh!
    Turbo::StreamsChannel.broadcast_replace_to(broadcast_channel, target: id, renderable: self, layout: false)
  end

  def title
    account.name
  end

  def subtitle
    return nil unless account.property?

    account.property.address
  end

  def active_tab
    tabs.find { |tab| tab == @active_tab&.to_sym } || tabs.first
  end

  def tabs
    case account.accountable_type
    when "Investment", "Crypto"
      [ :activity, :holdings ]
    when "Property", "Vehicle", "Loan"
      [ :activity, :overview ]
    else
      [ :activity ]
    end
  end

  def tab_content_for(tab)
    case tab
    when :activity
      activity_feed
    when :holdings, :overview
      # Accountable is responsible for implementing the partial in the correct folder
      render "#{account.accountable_type.downcase.pluralize}/tabs/#{tab}", account: account
    end
  end
end
