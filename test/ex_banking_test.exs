defmodule ExBankingTest do
  use ExUnit.Case, async: true

  setup_all do
    ExBanking.create_user("oscar")
  end

  describe "create_user/1" do
    test "should return {:error, :wrong_arguments} when user is non binary" do
      assert {:error, :wrong_arguments} = ExBanking.create_user(1)
      assert {:error, :wrong_arguments} = ExBanking.create_user(1.15)
      assert {:error, :wrong_arguments} = ExBanking.create_user(:atom)
      assert {:error, :wrong_arguments} = ExBanking.create_user(%{})
      assert {:error, :wrong_arguments} = ExBanking.create_user({})
      assert {:error, :wrong_arguments} = ExBanking.create_user(nil)
    end

    test "should return {:error, :wrong_arguments} when user is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.create_user("")
    end

    test "should return :ok when user is a non empty string" do
      assert :ok = ExBanking.create_user("bonbon")
    end

    test "should return {:error, :user_already_exists} if user with same name has been created before" do
      assert :ok = ExBanking.create_user("pompom")
      assert {:error, :user_already_exists} = ExBanking.create_user("pompom")
    end
  end
end
