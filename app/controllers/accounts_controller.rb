class AccountsController < ApplicationController
  include StreamExtensions

  before_action :set_account, only: %i[show clear_filter sparkline sync set_default remove_default]
  before_action :set_manageable_account, only: %i[toggle_active destroy unlink confirm_unlink select_provider]
  include Periodable

  def index
    @accessible_account_ids = Current.user.accessible_accounts.pluck(:id)
    @manual_accounts = family.accounts
          .listable_manual
          .where(id: @accessible_account_ids)
          .order(:name)
    @plaid_items = visible_provider_items(family.plaid_items.ordered.includes(:syncs, :plaid_accounts))
    @simplefin_items = visible_provider_items(family.simplefin_items.ordered.includes(:syncs))
    @lunchflow_items = visible_provider_items(family.lunchflow_items.ordered.includes(:syncs, :lunchflow_accounts))
    @enable_banking_items = visible_provider_items(family.enable_banking_items.ordered.includes(:syncs))
    @coinstats_items = visible_provider_items(family.coinstats_items.ordered.includes(:coinstats_accounts, :accounts, :syncs))
    @mercury_items = visible_provider_items(family.mercury_items.ordered.includes(:syncs, :mercury_accounts))
    @coinbase_items = visible_provider_items(family.coinbase_items.ordered.includes(:coinbase_accounts, :accounts, :syncs))
    @snaptrade_items = visible_provider_items(family.snaptrade_items.ordered.includes(:syncs, :snaptrade_accounts))
    @indexa_capital_items = visible_provider_items(family.indexa_capital_items.ordered.includes(:syncs, :indexa_capital_accounts))

    # Build sync stats maps for all providers
    build_sync_stats_maps

    # Prevent Turbo Drive from caching this page to ensure fresh account lists
    expires_now
    render layout: "settings"
  end

  def new
    # Get all registered providers with any credentials configured
    @provider_configs = Provider::Factory.registered_adapters.flat_map do |adapter_class|
      adapter_class.connection_configs(family: family)
    end
  end

  def sync_all
    family.sync_later
    redirect_to accounts_path, notice: t("accounts.sync_all.syncing")
  end

  def show
    @chart_view = params[:chart_view] || "balance"
    @tab = params[:tab]
    @q = account_search_params
    @selected_month = parse_activity_month
    @use_statement_cycles = ActiveModel::Type::Boolean.new.cast(@q[:use_statement_cycles])
    @activity_period_selection = build_activity_period_selection
    @period = filtered_chart_period || @period

    entries_scope = apply_account_activity_filters(@account.entries.where(excluded: false))
    @chart_summary_trend = filtered_chart_summary_trend(entries_scope)
    @display_balances_by_date = filtered_display_balances_by_date(entries_scope)
    entries = entries_scope.reverse_chronological

    @pagy, @entries = pagy(
      entries,
      limit: safe_per_page,
      params: request.query_parameters.except("tab").merge("tab" => "activity")
    )

    @activity_feed_data = Account::ActivityFeedData.new(
      @account,
      @entries,
      display_balances_by_date: @display_balances_by_date
    )
  end

  def clear_filter
    updated_params = {
      "q" => account_search_params.to_h,
      "tab" => params[:tab].presence || "activity"
    }

    q_params = updated_params["q"] || {}
    param_key = params[:param_key]
    param_value = params[:param_value]

    if q_params[param_key].is_a?(Array)
      q_params[param_key].delete(param_value)
      q_params.delete(param_key) if q_params[param_key].empty?
    else
      q_params.delete(param_key)
    end

    updated_params["q"] = q_params.presence

    redirect_to account_path(@account, updated_params)
  end

  def sync
    unless @account.syncing?
      if @account.linked?
        # Sync all provider items for this account
        # Each provider item will trigger an account sync when complete
        @account.account_providers.each do |account_provider|
          item = account_provider.adapter&.item
          item&.sync_later if item && !item.syncing?
        end
      else
        # Manual accounts just need balance materialization
        @account.sync_later
      end
    end

    redirect_to account_path(@account)
  end

  def sparkline
    etag_key = @account.family.build_cache_key("#{@account.id}_sparkline", invalidate_on_data_updates: true)

    # Short-circuit with 304 Not Modified when the client already has the latest version.
    # We defer the expensive series computation until we know the content is stale.
    if stale?(etag: etag_key, last_modified: @account.family.latest_sync_completed_at)
      @sparkline_series = @account.sparkline_series
      render layout: false
    end
  end

  def toggle_active
    if @account.active?
      @account.disable!
    elsif @account.disabled?
      @account.enable!
    end
    redirect_to accounts_path
  end

  def set_default
    unless @account.eligible_for_transaction_default?
      redirect_to accounts_path, alert: t("accounts.set_default.depository_only")
      return
    end

    Current.user.update!(default_account: @account)
    redirect_to accounts_path
  end

  def remove_default
    Current.user.update!(default_account: nil)
    redirect_to accounts_path
  end

  def destroy
    if @account.linked?
      redirect_to account_path(@account), alert: t("accounts.destroy.cannot_delete_linked")
    else
      @account.destroy_later
      redirect_to accounts_path, notice: t("accounts.destroy.success", type: @account.accountable_type)
    end
  end

  def confirm_unlink
    unless @account.linked?
      redirect_to account_path(@account), alert: t("accounts.unlink.not_linked")
    end
  end

  def unlink
    unless @account.linked?
      redirect_to account_path(@account), alert: t("accounts.unlink.not_linked")
      return
    end

    begin
      Account.transaction do
        # Detach holdings from provider links before destroying them
        provider_link_ids = @account.account_providers.pluck(:id)
        if provider_link_ids.any?
          Holding.where(account_provider_id: provider_link_ids).update_all(account_provider_id: nil)
        end

        # Capture provider accounts before clearing links (so we can destroy them)
        simplefin_account_to_destroy = @account.simplefin_account

        # Remove new system links (account_providers join table)
        # SnaptradeAccount records are preserved (not destroyed) so users can relink later.
        # This follows the Plaid pattern where the provider account survives as "unlinked".
        # SnapTrade has limited connection slots (5 free), so preserving the record avoids
        # wasting a slot on reconnect.
        @account.account_providers.destroy_all

        # Remove legacy system links (foreign keys)
        @account.update!(plaid_account_id: nil, simplefin_account_id: nil)

        # Destroy the SimplefinAccount record so it doesn't cause stale account issues
        # This is safe because:
        # - Account data (transactions, holdings, balances) lives on the Account, not SimplefinAccount
        # - SimplefinAccount only caches API data which is regenerated on reconnect
        # - If user reconnects SimpleFin later, a new SimplefinAccount will be created
        simplefin_account_to_destroy&.destroy!
      end

      redirect_to accounts_path, notice: t("accounts.unlink.success")
    rescue ActiveRecord::RecordInvalid => e
      redirect_to account_path(@account), alert: t("accounts.unlink.error", error: e.message)
    rescue StandardError => e
      Rails.logger.error "Failed to unlink account #{@account.id}: #{e.message}"
      redirect_to account_path(@account), alert: t("accounts.unlink.error", error: t("accounts.unlink.generic_error"))
    end
  end

  def select_provider
    if @account.linked?
      redirect_to account_path(@account), alert: t("accounts.select_provider.already_linked")
      return
    end

    account_type_name = @account.accountable_type

    # Get all available provider configs dynamically for this account type
    provider_configs = Provider::Factory.connection_configs_for_account_type(
      account_type: account_type_name,
      family: family
    )

    # Build available providers list with paths resolved for this specific account
    # Filter out providers that don't support linking to existing accounts
    @available_providers = provider_configs.filter_map do |config|
      next unless config[:existing_account_path].present?
      {
        name: config[:name],
        key: config[:key],
        description: config[:description],
        path: config[:existing_account_path].call(@account.id)
      }
    end

    if @available_providers.empty?
      redirect_to account_path(@account), alert: t("accounts.select_provider.no_providers")
    end
  end

  private
    def account_search_params
      params.fetch(:q, {}).permit(
        :search,
        :amount,
        :amount_operator,
        :start_date,
        :end_date,
        :month,
        :use_statement_cycles,
        types: [],
        status: [],
        categories: [],
        merchants: [],
        tags: [],
        owners: []
      )
    end

    def apply_account_activity_filters(scope)
      filtered_scope = scope

      filtered_scope = EntrySearch.apply_search_filter(filtered_scope.joins(:account), @q[:search])
      filtered_scope = apply_activity_date_filter(filtered_scope)
      filtered_scope = EntrySearch.apply_amount_filter(filtered_scope, @q[:amount], @q[:amount_operator])
      filtered_scope = EntrySearch.apply_status_filter(filtered_scope, @q[:status])

      if transaction_only_filters_present?
        matching_transaction_ids = Transaction::Search.new(
          Current.family,
          filters: transaction_search_filters,
          accessible_account_ids: [ @account.id ]
        ).transactions_scope.select(:id)

        filtered_scope = filtered_scope.where(entryable_type: "Transaction", entryable_id: matching_transaction_ids)
      end

      filtered_scope
    end

    def parse_activity_month
      raw_month = @q[:month]
      return nil if raw_month.blank?

      Date.strptime(raw_month, "%Y-%m").beginning_of_month
    rescue Date::Error
      nil
    end

    def build_activity_period_selection
      return nil unless @account.credit_card?
      return nil unless @selected_month

      StatementCycle::Selection.new(
        family: Current.family,
        accounts: [ @account ],
        statement_month: @selected_month,
        enabled: @use_statement_cycles
      )
    end

    def filtered_chart_period
      if @use_statement_cycles && @selected_month
        # Rule 1 and Rule 2 are enforced by CreditCard::CycleCalculator through the
        # shared StatementCycle::Selection, so the chart follows the statement cycle
        # that ends in the selected month with cutoff-day inclusion respected.
        # Rule 3 still applies here: this account uses its own configured cycle and
        # falls back to the calendar month when statement settings are missing.
        return @activity_period_selection&.envelope_period || Period.custom(
          start_date: @selected_month.beginning_of_month,
          end_date: @selected_month.end_of_month
        )
      end

      return nil if @q[:start_date].blank? && @q[:end_date].blank?

      start_date = parse_filter_date(@q[:start_date]) || @period.start_date
      end_date = parse_filter_date(@q[:end_date]) || @period.end_date
      start_date, end_date = [ start_date, end_date ].minmax

      Period.custom(start_date: start_date, end_date: end_date)
    end

    def filtered_display_balances_by_date(entries_scope)
      return {} unless owner_filters_present?

      Account::FilteredBalanceSummary.new(
        account: @account,
        entries: entries_scope,
        opening_balance_money: activity_balance_opening_money
      ).end_balances_by_date
    end

    def filtered_chart_summary_trend(entries_scope)
      return nil unless owner_filters_present?

      chart_entries = entries_scope.where(date: @period.date_range)

      Account::FilteredBalanceSummary.new(
        account: @account,
        entries: chart_entries,
        opening_balance_money: opening_balance_money_for(@period.start_date)
      ).trend
    end

    def activity_balance_opening_money
      opening_balance_money_for(activity_balance_start_date)
    end

    def activity_balance_start_date
      if @use_statement_cycles && @selected_month
        @activity_period_selection&.envelope_period&.start_date || @selected_month.beginning_of_month
      elsif @q[:start_date].present?
        parse_filter_date(@q[:start_date])
      end
    end

    def opening_balance_money_for(date)
      return nil unless date

      balance = @account.balances
        .where(currency: @account.currency)
        .where("date <= ?", date)
        .order(date: :desc)
        .first

      return Money.new(0, @account.currency) unless balance

      if balance.date == date
        balance.start_balance_money
      else
        balance.end_balance_money
      end
    end

    def apply_activity_date_filter(scope)
      if @use_statement_cycles && @selected_month
        # Rule 1 and Rule 2 are enforced by CreditCard::CycleCalculator through the
        # shared StatementCycle::Selection, so a selected statement month resolves to
        # the cycle that ends in that month, with cutoff-day inclusion respected.
        return @activity_period_selection.apply_to_scope(scope) if @activity_period_selection

        return scope.where(date: @selected_month.beginning_of_month..@selected_month.end_of_month)
      end

      EntrySearch.apply_date_filters(scope, @q[:start_date], @q[:end_date])
    end

    def transaction_only_filters_present?
      @q[:types].present? || @q[:categories].present? || @q[:merchants].present? || @q[:tags].present? || @q[:owners].present?
    end

    def owner_filters_present?
      @q[:owners].present?
    end

    def transaction_search_filters
      @q.to_h.slice("search", "amount", "amount_operator", "start_date", "end_date", "types", "status", "categories", "merchants", "tags", "owners")
    end

    def parse_filter_date(value)
      return nil if value.blank?

      Date.parse(value)
    rescue Date::Error
      nil
    end

    def family
      Current.family
    end

    def set_account
      @account = Current.user.accessible_accounts.find(params[:id])
    end

    def set_manageable_account
      @account = Current.user.accessible_accounts.find(params[:id])
      permission = @account.permission_for(Current.user)
      unless permission.in?([ :owner, :full_control ])
        respond_to do |format|
          format.html { redirect_to account_path(@account), alert: t("accounts.not_authorized") }
          format.turbo_stream { stream_redirect_to(account_path(@account), alert: t("accounts.not_authorized")) }
        end
        nil
      end
    end

    def visible_provider_items(items)
      items.select do |item|
        Current.user.admin? ||
          (item.respond_to?(:accounts) && (item.accounts.map(&:id) & @accessible_account_ids).any?)
      end
    end

    # Builds sync stats maps for all provider types to avoid N+1 queries in views
    def build_sync_stats_maps
      # SimpleFIN sync stats
      @simplefin_sync_stats_map = {}
      @simplefin_has_unlinked_map = {}
      @simplefin_unlinked_count_map = {}
      @simplefin_show_relink_map = {}
      @simplefin_duplicate_only_map = {}

      @simplefin_items.each do |item|
        latest_sync = item.syncs.ordered.first
        stats = latest_sync&.sync_stats || {}
        @simplefin_sync_stats_map[item.id] = stats
        @simplefin_has_unlinked_map[item.id] = item.family.accounts.listable_manual.exists?

        # Count unlinked accounts
        count = item.simplefin_accounts
          .left_joins(:account, :account_provider)
          .where(accounts: { id: nil }, account_providers: { id: nil })
          .count
        @simplefin_unlinked_count_map[item.id] = count

        # CTA visibility
        manuals_exist = @simplefin_has_unlinked_map[item.id]
        sfa_any = item.simplefin_accounts.loaded? ? item.simplefin_accounts.any? : item.simplefin_accounts.exists?
        @simplefin_show_relink_map[item.id] = (count.to_i == 0 && manuals_exist && sfa_any)

        # Check if all errors are duplicate-skips
        errors = Array(stats["errors"]).map { |e| e.is_a?(Hash) ? e["message"] || e[:message] : e.to_s }
        @simplefin_duplicate_only_map[item.id] = errors.present? && errors.all? { |m| m.to_s.downcase.include?("duplicate upstream account detected") }
      rescue => e
        Rails.logger.warn("SimpleFin stats map build failed for item #{item.id}: #{e.class} - #{e.message}")
        @simplefin_sync_stats_map[item.id] = {}
        @simplefin_show_relink_map[item.id] = false
        @simplefin_duplicate_only_map[item.id] = false
      end

      # Plaid sync stats
      @plaid_sync_stats_map = {}
      @plaid_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @plaid_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end

      # Lunchflow sync stats
      @lunchflow_sync_stats_map = {}
      @lunchflow_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @lunchflow_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end

      # Enable Banking sync stats
      @enable_banking_sync_stats_map = {}
      @enable_banking_latest_sync_error_map = {}
      @enable_banking_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @enable_banking_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
        @enable_banking_latest_sync_error_map[item.id] = latest_sync&.error
      end

      # CoinStats sync stats
      @coinstats_sync_stats_map = {}
      @coinstats_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @coinstats_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end

      # Mercury sync stats
      @mercury_sync_stats_map = {}
      @mercury_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @mercury_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end

      # Coinbase sync stats
      @coinbase_sync_stats_map = {}
      @coinbase_unlinked_count_map = {}
      @coinbase_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @coinbase_sync_stats_map[item.id] = latest_sync&.sync_stats || {}

        # Count unlinked accounts
        count = item.coinbase_accounts
          .left_joins(:account_provider)
          .where(account_providers: { id: nil })
          .count
        @coinbase_unlinked_count_map[item.id] = count
      end

      # IndexaCapital sync stats
      @indexa_capital_sync_stats_map = {}
      @indexa_capital_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @indexa_capital_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end
    end
end
