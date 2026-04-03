require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "should get index" do
    get accounts_url
    assert_response :success
  end

  test "should get show" do
    get account_url(@account)
    assert_response :success
  end

  test "credit card activity shows month and statement cycle filters" do
    get account_url(accounts(:credit_card))

    assert_response :success
    assert_select "#account-filters-menu", text: /Date/
    assert_select "#account-filters-menu", text: /Type/
    assert_select "#account-filters-menu", text: /Status/
    assert_select "#account-filters-menu", text: /Amount/
    assert_select "#account-filters-menu", text: /Category/
    assert_select "#account-filters-menu", text: /Tag/
    assert_select "#account-filters-menu", text: /Owner/
    assert_select "#account-filters-menu", text: /Merchant/
    assert_select "input[type='hidden'][name='q[month]']"
    assert_select "input[type='checkbox'][name='q[use_statement_cycles]']"
    assert_select "label", text: "Monthly statement"
  end

  test "non credit card activity does not show month or statement cycle filters" do
    get account_url(@account)

    assert_response :success
    assert_select "#account-filters-menu", text: /Date/
    assert_select "input[type='hidden'][name='q[month]']", count: 0
    assert_select "input[type='checkbox'][name='q[use_statement_cycles]']", count: 0
  end

  test "credit card activity filters by selected statement cycle" do
    credit_card_account = accounts(:credit_card)
    credit_card_account.credit_card.update!(
      statement_cutoff_mode: "fixed_day",
      statement_cutoff_day: 15,
      statement_includes_cutoff_day: true
    )

    create_transaction(
      account: credit_card_account,
      name: "Included cycle start",
      date: Date.new(2026, 2, 15),
      amount: -25
    )
    create_transaction(
      account: credit_card_account,
      name: "Included cycle end",
      date: Date.new(2026, 3, 15),
      amount: -30
    )
    create_transaction(
      account: credit_card_account,
      name: "Before selected cycle",
      date: Date.new(2026, 2, 14),
      amount: -10
    )
    create_transaction(
      account: credit_card_account,
      name: "After selected cycle",
      date: Date.new(2026, 3, 16),
      amount: -40
    )

    get account_url(credit_card_account, q: { month: "2026-03", use_statement_cycles: "1" })

    assert_response :success
    assert_includes @response.body, "Included cycle start"
    assert_includes @response.body, "Included cycle end"
    assert_not_includes @response.body, "Before selected cycle"
    assert_not_includes @response.body, "After selected cycle"
  end

  test "credit card activity falls back to calendar month when statement cycle is not configured" do
    credit_card_account = accounts(:credit_card)

    create_transaction(
      account: credit_card_account,
      name: "March calendar transaction",
      date: Date.new(2026, 3, 10),
      amount: -25
    )
    create_transaction(
      account: credit_card_account,
      name: "February calendar transaction",
      date: Date.new(2026, 2, 28),
      amount: -30
    )

    get account_url(credit_card_account, q: { month: "2026-03", use_statement_cycles: "1" })

    assert_response :success
    assert_includes @response.body, "March calendar transaction"
    assert_not_includes @response.body, "February calendar transaction"
  end

  test "account activity renders filter chips from url params" do
    get account_url(
      accounts(:credit_card),
      q: {
        start_date: "2026-03-01",
        end_date: "2026-03-31",
        owners: [ "partner" ],
        use_statement_cycles: "1",
        month: "2026-03"
      }
    )

    assert_response :success
    assert_includes @response.body, "2026-03-01"
    assert_includes @response.body, "2026-03-31"
    assert_includes @response.body, "partner"
    assert_includes @response.body, "Mar 2026"
    assert_includes @response.body, "Monthly statement"
  end

  test "account chart follows explicit activity date filters" do
    get account_url(
      @account,
      q: {
        start_date: "2026-03-10",
        end_date: "2026-03-20"
      }
    )

    assert_response :success
    assert_includes @response.body, "Mar 10, 2026 to Mar 20, 2026"
    assert_select "select[name='period'] option[selected][hidden][value='']", text: "Custom"
    assert_select "select[name='period'] option", text: "Custom", count: 1
  end

  test "credit card chart follows selected statement cycle range" do
    credit_card_account = accounts(:credit_card)
    credit_card_account.credit_card.update!(
      statement_cutoff_mode: "fixed_day",
      statement_cutoff_day: 15,
      statement_includes_cutoff_day: true
    )

    get account_url(credit_card_account, q: { month: "2026-03", use_statement_cycles: "1" })

    assert_response :success
    assert_includes @response.body, "Feb 15, 2026 to Mar 15, 2026"
  end

  test "activity pagination keeps activity tab when loaded from holdings tab" do
    investment = accounts(:investment)

    11.times do |i|
      Entry.create!(
        account: investment,
        name: "Test investment activity #{i}",
        date: Date.current - i.days,
        amount: 10 + i,
        currency: investment.currency,
        entryable: Transaction.new
      )
    end

    get account_url(investment, tab: "holdings")

    assert_response :success
    assert_select "a[href*='page=2'][href*='tab=activity']"
    assert_select "a[href*='page=2'][href*='tab=holdings']", count: 0
  end

  test "should sync account" do
    post sync_account_url(@account)
    assert_redirected_to account_url(@account)
  end

  test "should get sparkline" do
    get sparkline_account_url(@account)
    assert_response :success
  end

  test "destroys account" do
    delete account_url(@account)
    assert_redirected_to accounts_path
    assert_enqueued_with job: DestroyJob
    assert_equal "Depository account scheduled for deletion", flash[:notice]
  end

  test "syncing linked account triggers sync for all provider items" do
    plaid_account = plaid_accounts(:one)
    plaid_item = plaid_account.plaid_item
    AccountProvider.create!(account: @account, provider: plaid_account)

    # Reload to ensure the account has the provider association loaded
    @account.reload

    # Mock at the class level since controller loads account from DB
    Account.any_instance.expects(:syncing?).returns(false)
    PlaidItem.any_instance.expects(:syncing?).returns(false)
    PlaidItem.any_instance.expects(:sync_later).once

    post sync_account_url(@account)
    assert_redirected_to account_url(@account)
  end

  test "syncing unlinked account calls account sync_later" do
    Account.any_instance.expects(:syncing?).returns(false)
    Account.any_instance.expects(:sync_later).once

    post sync_account_url(@account)
    assert_redirected_to account_url(@account)
  end

  test "confirms unlink for linked account" do
    plaid_account = plaid_accounts(:one)
    AccountProvider.create!(account: @account, provider: plaid_account)

    get confirm_unlink_account_url(@account)
    assert_response :success
  end

  test "redirects when confirming unlink for unlinked account" do
    get confirm_unlink_account_url(@account)
    assert_redirected_to account_url(@account)
    assert_equal "Account is not linked to a provider", flash[:alert]
  end

  test "unlinks linked account successfully with new system" do
    plaid_account = plaid_accounts(:one)
    AccountProvider.create!(account: @account, provider: plaid_account)
    @account.reload

    assert @account.linked?

    delete unlink_account_url(@account)
    @account.reload

    assert_not @account.linked?
    assert_redirected_to accounts_path
    assert_equal "Account unlinked successfully. It is now a manual account.", flash[:notice]
  end

  test "unlinks linked account successfully with legacy system" do
    plaid_account = plaid_accounts(:one)
    @account.update!(plaid_account_id: plaid_account.id)
    @account.reload

    assert @account.linked?

    delete unlink_account_url(@account)
    @account.reload

    assert_not @account.linked?
    assert_nil @account.plaid_account_id
    assert_redirected_to accounts_path
    assert_equal "Account unlinked successfully. It is now a manual account.", flash[:notice]
  end

  test "redirects when unlinking unlinked account" do
    delete unlink_account_url(@account)
    assert_redirected_to account_url(@account)
    assert_equal "Account is not linked to a provider", flash[:alert]
  end

  test "unlinked account can be deleted" do
    plaid_account = plaid_accounts(:one)
    AccountProvider.create!(account: @account, provider: plaid_account)
    @account.reload

    # Cannot delete while linked
    delete account_url(@account)
    assert_redirected_to account_url(@account)
    assert_equal "Cannot delete a linked account. Please unlink it first.", flash[:alert]

    # Unlink the account
    delete unlink_account_url(@account)
    @account.reload

    # Now can delete
    delete account_url(@account)
    assert_redirected_to accounts_path
    assert_enqueued_with job: DestroyJob
    assert_equal "Depository account scheduled for deletion", flash[:notice]
  end

  test "disabling an account keeps it visible on index" do
    @account.disable!

    get accounts_path

    assert_response :success
    assert_includes @response.body, @account.name
  end

  test "toggle_active disables and re-enables an account" do
    patch toggle_active_account_url(@account)
    assert_redirected_to accounts_path
    @account.reload
    assert @account.disabled?

    patch toggle_active_account_url(@account)
    assert_redirected_to accounts_path
    @account.reload
    assert @account.active?
  end

  test "select_provider shows available providers" do
    get select_provider_account_url(@account)
    assert_response :success
  end

  test "set_default sets user default account" do
    patch set_default_account_url(@account)
    assert_redirected_to accounts_path
    @user.reload
    assert_equal @account.id, @user.default_account_id
  end

  test "set_default rejects ineligible account type" do
    investment = accounts(:investment)

    patch set_default_account_url(investment)
    assert_redirected_to accounts_path
    assert_equal I18n.t("accounts.set_default.depository_only"), flash[:alert]

    @user.reload
    assert_not_equal investment.id, @user.default_account_id
  end

  test "remove_default clears user default account" do
    @user.update!(default_account: @account)

    patch remove_default_account_url(@account)
    assert_redirected_to accounts_path

    @user.reload
    assert_nil @user.default_account_id
  end

  test "select_provider redirects for already linked account" do
    plaid_account = plaid_accounts(:one)
    AccountProvider.create!(account: @account, provider: plaid_account)

    get select_provider_account_url(@account)
    assert_redirected_to account_url(@account)
    assert_equal "Account is already linked to a provider", flash[:alert]
  end

  test "unlink preserves SnaptradeAccount record" do
    snaptrade_account = snaptrade_accounts(:fidelity_401k)
    investment = accounts(:investment)
    AccountProvider.create!(account: investment, provider: snaptrade_account)
    investment.reload

    assert investment.linked?

    delete unlink_account_url(investment)
    investment.reload

    assert_not investment.linked?
    assert_redirected_to accounts_path
    # SnaptradeAccount should still exist (not destroyed)
    assert SnaptradeAccount.exists?(snaptrade_account.id), "SnaptradeAccount should be preserved after unlink"
    # But AccountProvider should be gone
    assert_not AccountProvider.exists?(provider_type: "SnaptradeAccount", provider_id: snaptrade_account.id)
  end

  test "unlink does not enqueue SnapTrade cleanup job" do
    snaptrade_account = snaptrade_accounts(:fidelity_401k)
    investment = accounts(:investment)
    AccountProvider.create!(account: investment, provider: snaptrade_account)
    investment.reload

    assert_no_enqueued_jobs(only: SnaptradeConnectionCleanupJob) do
      delete unlink_account_url(investment)
    end
  end

  test "unlink detaches holdings from SnapTrade provider" do
    snaptrade_account = snaptrade_accounts(:fidelity_401k)
    investment = accounts(:investment)
    ap = AccountProvider.create!(account: investment, provider: snaptrade_account)

    # Assign a holding to this provider
    holding = holdings(:one)
    holding.update!(account_provider: ap)

    delete unlink_account_url(investment)
    holding.reload

    assert_nil holding.account_provider_id, "Holding should be detached from provider after unlink"
  end
end

class AccountsControllerSimplefinCtaTest < ActionDispatch::IntegrationTest
  fixtures :users, :families

  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
  end

  test "when unlinked SFAs exist and manuals exist, shows setup button only" do
    item = SimplefinItem.create!(family: @family, name: "Conn", access_url: "https://example.com/access")
    # Unlinked SFA (no account and no provider link)
    item.simplefin_accounts.create!(name: "A", account_id: "sf_a", currency: "USD", current_balance: 1, account_type: "depository")
    # One manual account available
    Account.create!(family: @family, name: "Manual A", currency: "USD", balance: 0, accountable_type: "Depository", accountable: Depository.create!(subtype: "checking"))

    get accounts_path
    assert_response :success
    # Expect setup link present
    assert_includes @response.body, setup_accounts_simplefin_item_path(item)
    # Relink modal (SimpleFin-specific) should not be present anymore
    refute_includes @response.body, "Link existing accounts"
  end

  test "when SFAs exist and none unlinked and manuals exist, no relink modal is shown (unified flow)" do
    item = SimplefinItem.create!(family: @family, name: "Conn2", access_url: "https://example.com/access")
    # Create a manual linked to SFA so unlinked count == 0
    sfa = item.simplefin_accounts.create!(name: "B", account_id: "sf_b", currency: "USD", current_balance: 1, account_type: "depository")
    linked = Account.create!(family: @family, name: "Linked", currency: "USD", balance: 0, accountable_type: "Depository", accountable: Depository.create!(subtype: "savings"))
    # Legacy association sufficient to count as linked
    sfa.update!(account: linked)

    # Also create another manual account to make manuals_exist true
    Account.create!(family: @family, name: "Manual B", currency: "USD", balance: 0, accountable_type: "Depository", accountable: Depository.create!(subtype: "checking"))

    get accounts_path
    assert_response :success
    # The SimpleFin-specific relink modal is removed in favor of unified provider flow
    refute_includes @response.body, "Link existing accounts"
  end

  test "when no SFAs exist, shows neither CTA" do
    item = SimplefinItem.create!(family: @family, name: "Conn3", access_url: "https://example.com/access")

    get accounts_path
    assert_response :success
    refute_includes @response.body, setup_accounts_simplefin_item_path(item)
    refute_includes @response.body, "Link existing accounts"
  end
end
