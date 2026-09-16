require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "invalid with duplicate name" do
    category = Category.new(name: categories(:one).name)
    assert_not category.valid?
  end

  test "cannot destroy category with services" do
    category = categories(:one)
    assert_not category.destroy
  end
end
