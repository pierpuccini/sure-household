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
    mapping = @import.mappings.create!(key: "Visa Import", type: "Import::AccountMapping")

    get new_account_import_mapping_path(@import, mapping)

    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "option[value='CreditCard']"
  end

  test "updates account mapping with create new and selected account type" do
    mapping = @import.mappings.create!(key: "Visa Import", type: "Import::AccountMapping")

    patch import_mapping_path(@import, mapping), params: {
      import_mapping: {
        type: "Import::AccountMapping",
        key: "Visa Import",
        mappable_type: "Account",
        mappable_id: Import::Mapping::CREATE_NEW_KEY,
        value: "CreditCard"
      }
    }

    mapping.reload

    assert mapping.create_when_empty?
    assert_equal "CreditCard", mapping.value
    assert_nil mapping.mappable
    assert_redirected_to import_confirm_path(@import)
  end
end
