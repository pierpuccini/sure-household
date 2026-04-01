require "test_helper"

class BudgetsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
  end

  test "show renders statement-cycle toggle and preserves it on today link" do
    get budget_path(Budget.date_to_param(Date.new(2026, 3, 1)), use_statement_cycles: "1")

    assert_response :ok
    assert_select "a", text: "Statement cycles: On"
    assert_select "a[href*='use_statement_cycles=1']", text: "Today"
    assert_select "span", text: "Statement cycles"
  end

  test "show renders owner breakdown toggle" do
    get budget_path(Budget.date_to_param(Date.current), owner_breakdown: "1")

    assert_response :ok
    assert_select "a", text: "Owner breakdown: On"
    assert_select "a[href*='owner_breakdown=1']", text: "Today"
  end
end
