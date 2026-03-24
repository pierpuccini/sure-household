require "test_helper"

class UserDashboardPreferencesTest < ActiveSupport::TestCase
  test "tracks hidden dashboard sections in user preferences" do
    user = users(:family_admin)

    user.update_dashboard_preferences("hidden_sections" => { "cashflow_sankey" => true })

    assert user.dashboard_section_hidden?("cashflow_sankey")
    assert_includes user.hidden_dashboard_section_keys, "cashflow_sankey"
  end
end
