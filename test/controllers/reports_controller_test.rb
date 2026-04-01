require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
  end

  test "index renders successfully" do
    get reports_path
    assert_response :ok
  end

  test "index with monthly period" do
    get reports_path(period_type: :monthly)
    assert_response :ok
    assert_select "h1", text: I18n.t("reports.index.title")
    assert_select "a[aria-label='Edit monthly report period']"
  end

  test "index shows monthly statement-cycle picker when editing monthly period" do
    get reports_path(period_type: :monthly, edit_month_picker: true)

    assert_response :ok
    assert_select "input[type='month'][name='statement_month']"
    assert_select "input[type='checkbox'][name='use_statement_cycles']"
  end

  test "index with quarterly period" do
    get reports_path(period_type: :quarterly)
    assert_response :ok
  end

  test "index with ytd period" do
    get reports_path(period_type: :ytd)
    assert_response :ok
  end

  test "index with custom period and date range" do
    get reports_path(
      period_type: :custom,
      start_date: 1.month.ago.to_date.to_s,
      end_date: Date.current.to_s
    )
    assert_response :ok
  end

  test "index with last 6 months period" do
    get reports_path(period_type: :last_6_months)
    assert_response :ok
  end

  test "index shows empty state when no transactions" do
    # Delete all transactions for the family by deleting from accounts
    @family.accounts.each { |account| account.entries.destroy_all }

    get reports_path
    assert_response :ok
    assert_select "h3", text: I18n.t("reports.empty_state.title")
  end

  test "index with budget performance for current month" do
    # Create a budget for current month
    budget = Budget.find_or_bootstrap(@family, start_date: Date.current.beginning_of_month)
    category = @family.categories.expenses.first

    # Fail fast if test setup is incomplete
    assert_not_nil category, "Test setup failed: no expense category found for family"
    assert_not_nil budget, "Test setup failed: budget could not be created or found"

    # Find or create budget category to avoid duplicate errors
    budget_category = budget.budget_categories.find_or_initialize_by(category: category)
    budget_category.budgeted_spending = Money.new(50000, @family.currency)
    budget_category.save!

    get reports_path(period_type: :monthly)
    assert_response :ok
  end

  test "index calculates summary metrics correctly" do
    get reports_path(period_type: :monthly)
    assert_response :ok
    assert_select "h3", text: I18n.t("reports.summary.total_income")
    assert_select "h3", text: I18n.t("reports.summary.total_expenses")
    assert_select "h3", text: I18n.t("reports.summary.net_savings")
  end

  test "index builds trends data" do
    get reports_path(period_type: :monthly)
    assert_response :ok
    assert_select "h2", text: I18n.t("reports.trends.title")
    assert_select "thead" do
      assert_select "th", text: I18n.t("reports.trends.month")
    end
  end

  test "index handles invalid date parameters gracefully" do
    get reports_path(
      period_type: :custom,
      start_date: "invalid-date",
      end_date: "also-invalid"
    )
    assert_response :ok # Should not crash, uses defaults
  end

  test "index swaps dates when end_date is before start_date" do
    start_date = Date.current
    end_date = 1.month.ago.to_date

    get reports_path(
      period_type: :custom,
      start_date: start_date.to_s,
      end_date: end_date.to_s
    )

    assert_response :ok
    # Should show flash message about invalid date range
    assert flash[:alert].present?, "Flash alert should be present"
    assert_match /End date cannot be before start date/, flash[:alert]
    # Verify the response body contains the swapped date range in the correct order
    assert_includes @response.body, end_date.strftime("%b %-d, %Y")
    assert_includes @response.body, start_date.strftime("%b %-d, %Y")
  end

  test "statement-cycle monthly report uses month-based header text" do
    get reports_path(period_type: :monthly, statement_month: "2026-03", use_statement_cycles: "1")

    assert_response :ok
    assert_includes @response.body, "Showing March 2026 statement-cycle data"
  end

  test "statement-cycle monthly report includes credit-card cycle transactions and calendar-month non-credit-card transactions" do
    category = @family.categories.create!(name: "Statement Cycle Test", color: "#123456")
    credit_cards(:one).update!(
      statement_cutoff_mode: "fixed_day",
      statement_cutoff_day: 15,
      statement_includes_cutoff_day: true
    )

    create_transaction(
      account: accounts(:credit_card),
      category: category,
      name: "Included card cycle purchase",
      amount: 9876,
      date: Date.new(2026, 2, 20)
    )
    create_transaction(
      account: accounts(:credit_card),
      category: category,
      name: "Excluded pre-cycle purchase",
      amount: 1111,
      date: Date.new(2026, 2, 10)
    )
    create_transaction(
      account: accounts(:depository),
      category: category,
      name: "Included calendar purchase",
      amount: 5432,
      date: Date.new(2026, 3, 5)
    )

    get reports_path(
      period_type: :monthly,
      statement_month: "2026-03",
      use_statement_cycles: "1",
      filter_category_id: category.id
    )

    assert_response :ok
    assert_includes @response.body, "Statement Cycle Test"
    assert_includes @response.body, Money.new(15308, @family.currency).format
  end

  test "owner breakdown shows owner spending cards and repeated activity sections" do
    category = @family.categories.create!(name: "Owner Breakdown Test", color: "#654321")

    create_transaction(
      account: accounts(:depository),
      category: category,
      name: "Me purchase",
      amount: 2500,
      date: Date.current.beginning_of_month + 2.days,
      owner: "me"
    )
    create_transaction(
      account: accounts(:depository),
      category: category,
      name: "Partner purchase",
      amount: 3500,
      date: Date.current.beginning_of_month + 3.days,
      owner: "partner"
    )
    create_transaction(
      account: accounts(:depository),
      category: category,
      name: "Shared purchase",
      amount: 4500,
      date: Date.current.beginning_of_month + 4.days,
      owner: "shared"
    )

    get reports_path(period_type: :monthly, owner_breakdown: "1")

    assert_response :ok
    assert_includes @response.body, "Owner breakdown: On"
    assert_includes @response.body, "Me spending"
    assert_includes @response.body, "Partner spending"
    assert_includes @response.body, "Shared spending"
    assert_select "h3", text: "Me"
    assert_select "h3", text: "Partner"
    assert_select "h3", text: "Shared"
  end

  test "spending patterns returns data when expense transactions exist" do
    # Create expense category
    expense_category = @family.categories.create!(
      name: "Test Groceries"
    )

    # Create account
    account = @family.accounts.first

    # Create expense transaction on a weekday (Monday)
    weekday_date = Date.current.beginning_of_month + 2.days
    weekday_date = weekday_date.next_occurring(:monday)

    entry = account.entries.create!(
      name: "Grocery shopping",
      date: weekday_date,
      amount: 50.00,
      currency: "USD",
      entryable: Transaction.new(
        category: expense_category,
        kind: "standard"
      )
    )

    # Create expense transaction on a weekend (Saturday)
    weekend_date = weekday_date.next_occurring(:saturday)

    weekend_entry = account.entries.create!(
      name: "Weekend shopping",
      date: weekend_date,
      amount: 75.00,
      currency: "USD",
      entryable: Transaction.new(
        category: expense_category,
        kind: "standard"
      )
    )

    get reports_path(period_type: :monthly)
    assert_response :ok

    # Verify spending patterns shows data (not the "no data" message)
    assert_select ".text-center.py-8.text-subdued", { text: /No spending data/, count: 0 }, "Should not show 'No spending data' message when transactions exist"
  end

  test "export transactions with API key authentication" do
    # Use an active API key with read permissions
    api_key = api_keys(:active_key)

    # Make sure the API key has the correct source
    api_key.update!(source: "web") unless api_key.source == "web"

    get export_transactions_reports_path(
      format: :csv,
      period_type: :ytd,
      start_date: Date.current.beginning_of_year,
      end_date: Date.current,
      api_key: api_key.plain_key
    )

    assert_response :ok
    assert_equal "text/csv", @response.media_type
    assert_match /Category/, @response.body
  end

  test "export transactions with invalid API key" do
    get export_transactions_reports_path(
      format: :csv,
      period_type: :ytd,
      api_key: "invalid_key"
    )

    assert_response :unauthorized
    assert_match /Invalid or expired API key/, @response.body
  end

  test "export transactions without API key uses session auth" do
    # Should use normal session-based authentication
    # The setup already signs in @user = users(:family_admin)
    assert_not_nil @user, "User should be set in test setup"
    assert_not_nil @family, "Family should be set in test setup"

    get export_transactions_reports_path(
      format: :csv,
      period_type: :ytd,
      start_date: Date.current.beginning_of_year,
      end_date: Date.current
    )

    assert_response :ok, "Export should work with session auth. Response: #{@response.body}"
    assert_equal "text/csv", @response.media_type
  end

  test "export transactions swaps dates when end_date is before start_date" do
    start_date = Date.current
    end_date = 1.month.ago.to_date

    get export_transactions_reports_path(
      format: :csv,
      period_type: :custom,
      start_date: start_date.to_s,
      end_date: end_date.to_s
    )

    assert_response :ok
    assert_equal "text/csv", @response.media_type
    # Verify the CSV content is generated (should not crash)
    assert_not_nil @response.body
  end

  test "index groups transactions by parent and subcategories" do
    # Create parent category with subcategories
    parent_category = @family.categories.create!(name: "Entertainment", color: "#FF5733")
    subcategory_movies = @family.categories.create!(name: "Movies", parent: parent_category, color: "#33FF57")
    subcategory_games = @family.categories.create!(name: "Games", parent: parent_category, color: "#5733FF")

    # Create transactions using helper
    create_transaction(account: @family.accounts.first, name: "Cinema ticket", amount: 15, category: subcategory_movies)
    create_transaction(account: @family.accounts.first, name: "Video game", amount: 60, category: subcategory_games)

    get reports_path(period_type: :monthly)
    assert_response :ok

    # Parent category
    assert_select "tr[data-category='category-#{parent_category.id}']", text: /^Entertainment/

    # Subcategories
    assert_select "tr[data-category='category-#{subcategory_movies.id}']", text: /^Movies/
    assert_select "tr[data-category='category-#{subcategory_games.id}']", text: /^Games/
  end
end
