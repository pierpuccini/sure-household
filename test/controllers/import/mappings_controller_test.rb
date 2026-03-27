require "test_helper"

class Import::MappingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)

    @import = imports(:transaction)
  end

  test "updates mapping" do
    mapping = import_mappings(:one)
    new_category = categories(:income)

    patch import_mapping_path(@import, mapping), params: {
      import_mapping: {
        mappable_type: "Category",
        mappable_id: new_category.id,
        key: "Food"
      }
    }

    mapping.reload

    assert_equal new_category, mapping.mappable
    assert_equal "Food", mapping.key

    assert_redirected_to import_confirm_path(@import)
  end

  test "shows new account modal for account mappings" do
    mapping = @import.mappings.new(key: "Visa Import", type: "Import::AccountMapping", create_when_empty: true)
    mapping.save!(validate: false)

    get new_account_import_mapping_path(@import, mapping)

    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "a[href=?]", new_credit_card_path(
      return_to: import_confirm_path(@import, step: 3),
      import_id: @import.id,
      import_mapping_id: mapping.id,
      account_name: "Visa Import"
    ), text: "Credit Card"
  end
end
