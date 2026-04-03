module AccountsHelper
  def summary_card(title:, &block)
    content = capture(&block)
    render "accounts/summary_card", title: title, content: content
  end

  def sync_path_for(account)
    # Always use the account sync path, which handles syncing all providers
    sync_account_path(account)
  end

  def account_activity_search_filters(account)
    [
      { key: "date_filter", label: t("accounts.show.activity.date"), icon: "calendar" },
      { key: "type_filter", label: t("transactions.search.menu.type_filter"), icon: "tag" },
      { key: "status_filter", label: t("accounts.show.activity.status"), icon: "clock" },
      { key: "amount_filter", label: t("transactions.search.menu.amount_filter"), icon: "hash" },
      { key: "category_filter", label: t("transactions.search.menu.category_filter"), icon: "shapes" },
      { key: "tag_filter", label: t("transactions.search.menu.tag_filter"), icon: "tags" },
      { key: "owner_filter", label: "Owner", icon: "users" },
      { key: "merchant_filter", label: "Merchant", icon: "store" }
    ]
  end

  def account_activity_default_filter(account)
    account_activity_search_filters(account).first
  end

  def account_activity_search_filter_partial_path(filter)
    return "accounts/searches/filters/date_filter" if filter[:key] == "date_filter"
    return "accounts/searches/filters/status_filter" if filter[:key] == "status_filter"

    "transactions/searches/filters/#{filter[:key]}"
  end
end
