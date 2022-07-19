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

  describe "deposit/3" do
    test "should return {:error, :wrong_arguments} when user argument is non binary" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(1, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit(1.15, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit(:atom, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit(%{}, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit({}, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit(nil, 500.123, "EUR")
    end

    test "should return {:error, :wrong_arguments} when amount argument is non number" do
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", "500", "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", "500.123", "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", :atom, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", %{}, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", {}, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", nil, "EUR")
    end

    test "should return {:error, :wrong_arguments} when currency argument is non binary" do
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", 500.123, 1)
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", 500.123, 1.15)
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", 500.123, :atom)
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", 500.123, %{})
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", 500.123, {})
      assert {:error, :wrong_arguments} = ExBanking.deposit("oscar", 500.123, nil)
    end

    test "should return {:error, :user_does_not_exist} when user does not exists" do
      assert {:error, :user_does_not_exist} =
               ExBanking.deposit("non_existence_user", 500.123, "EUR")
    end

    test "should increase balance according to the input currency" do
      ExBanking.create_user("test_deposit_1")
      assert {:ok, 500.50} = ExBanking.deposit("test_deposit_1", 500.50, "EUR")
      assert {:ok, 1001.0} = ExBanking.deposit("test_deposit_1", 500.50, "EUR")
      assert {:ok, 2001.0} = ExBanking.deposit("test_deposit_1", 1000, "EUR")
      assert {:ok, 123.12} = ExBanking.deposit("test_deposit_1", 123.12, "IDR")
      assert {:ok, 2001.0} = ExBanking.get_balance("test_deposit_1", "EUR")
    end

    test "should be able to deposit 0 amount" do
      ExBanking.create_user("test_deposit_0")
      assert {:ok, 0.0} = ExBanking.deposit("test_deposit_0", 0, "EUR")
      assert {:ok, 0.0} = ExBanking.get_balance("test_deposit_0", "EUR")
    end

    test "should return balance with a precision of 2 decimal places" do
      ExBanking.create_user("test_deposit_2")
      assert {:ok, 500.50} = ExBanking.deposit("test_deposit_2", 500.501, "EUR")
    end

    test "should always down round the new balance" do
      ExBanking.create_user("test_deposit_3")
      assert {:ok, 500.12} = ExBanking.deposit("test_deposit_3", 500.129, "EUR")
    end

    test "should be able to process no more than 10 deposits at the same time for a single user" do
      ExBanking.create_user("test_deposit_4")

      results =
        1..15
        |> Enum.map(fn i ->
          Task.async(fn -> ExBanking.deposit("test_deposit_4", 1, "#{inspect(i)}") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 == {:error, :too_many_requests_to_user})) == 5
    end

    test "should be able to processs deposits for different users at the same time" do
      ExBanking.create_user("1")
      ExBanking.create_user("2")

      results =
        for user <- 1..2, currency <- 1..15 do
          {Integer.to_string(user), Integer.to_string(currency)}
        end
        |> Enum.map(fn {user, currency} ->
          Task.async(fn -> ExBanking.deposit(user, 1, currency) end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 == {:error, :too_many_requests_to_user})) == 10
    end

    test "should be able to withstand burst request" do
      ExBanking.create_user("deposit_burst")

      results =
        1..100
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.deposit("deposit_burst", 1, "EUR") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 != {:error, :too_many_requests_to_user})) == 10
      assert {:ok, 10.0} = ExBanking.get_balance("deposit_burst", "EUR")
    end
  end

  describe "withdraw/3" do
    test "should return {:error, :wrong_arguments} when user argument is non binary" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(1, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(1.15, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(:atom, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(%{}, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw({}, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(nil, 500.123, "EUR")
    end

    test "should return {:error, :wrong_arguments} when amount argument is non number" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", "500", "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", "500.123", "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", :atom, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", %{}, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", {}, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", nil, "EUR")
    end

    test "should return {:error, :wrong_arguments} when currency argument is non binary" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", 500.123, 1)
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", 500.123, 1.15)
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", 500.123, :atom)
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", 500.123, %{})
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", 500.123, {})
      assert {:error, :wrong_arguments} = ExBanking.withdraw("oscar", 500.123, nil)
    end

    test "should return {:error, :user_does_not_exist} when user does not exists" do
      assert {:error, :user_does_not_exist} =
               ExBanking.withdraw("non_existence_user", 500.123, "EUR")
    end

    test "should return {:error, :not_enough_money} when user does not have enough balance" do
      ExBanking.create_user("broke_user")
      ExBanking.deposit("broke_user", 500.255, "EUR")
      assert {:error, :not_enough_money} = ExBanking.withdraw("broke_user", 10000, "EUR")
    end

    test "should return {:error, :not_enough_money} when user does not have an account with the related currency" do
      ExBanking.create_user("poly")
      assert {:error, :not_enough_money} = ExBanking.withdraw("poly", 20, "EUR")
    end

    test "should deduct balance according to the input currency" do
      ExBanking.create_user("test_withdraw_1")
      ExBanking.deposit("test_withdraw_1", 1000, "EUR")
      ExBanking.deposit("test_withdraw_1", 1000, "IDR")
      assert {:ok, 800.0} = ExBanking.withdraw("test_withdraw_1", 200, "EUR")
      assert {:ok, 700.0} = ExBanking.withdraw("test_withdraw_1", 100, "EUR")
      assert {:ok, 650.0} = ExBanking.withdraw("test_withdraw_1", 50, "EUR")
      assert {:ok, 990.0} = ExBanking.withdraw("test_withdraw_1", 10, "IDR")
    end

    test "should be able to withdraw 0 amount" do
      ExBanking.create_user("test_withdraw_0")
      ExBanking.deposit("test_withdraw_0", 1000, "EUR")
      assert {:ok, 1000.0} = ExBanking.withdraw("test_withdraw_0", 0, "EUR")
    end

    test "should be able to withdraw 0 amount even if the currency does not exists yet" do
      ExBanking.create_user("test_withdraw_without_account")
      assert {:ok, 0.0} = ExBanking.withdraw("test_withdraw_without_account", 0, "EUR")
    end

    test "should return balance with a precision of 2 decimal places" do
      ExBanking.create_user("test_withdraw_2")
      ExBanking.deposit("test_withdraw_2", 1000.501, "EUR")
      assert {:ok, 500.50} = ExBanking.withdraw("test_withdraw_2", 500, "EUR")
    end

    test "should always down round the new balance" do
      ExBanking.create_user("test_withdraw_3")
      ExBanking.deposit("test_withdraw_3", 1000.509, "EUR")
      assert {:ok, 500.50} = ExBanking.withdraw("test_withdraw_3", 500, "EUR")
    end

    test "should be able to process no more than 10 withdraws at the same time for a single user" do
      ExBanking.create_user("test_withdraw_4")

      results =
        1..15
        |> Enum.map(fn i ->
          Task.async(fn -> ExBanking.withdraw("test_withdraw_4", 1, "#{inspect(i)}") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 == {:error, :too_many_requests_to_user})) == 5
    end

    test "should be able to processs withdraw for different users at the same time" do
      ExBanking.create_user("3")
      ExBanking.create_user("4")

      results =
        for user <- 3..4, currency <- 1..15 do
          {Integer.to_string(user), Integer.to_string(currency)}
        end
        |> Enum.map(fn {user, currency} ->
          Task.async(fn -> ExBanking.withdraw(user, 1, currency) end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 == {:error, :too_many_requests_to_user})) == 10
    end

    test "should be able to withstand burst request" do
      ExBanking.create_user("withdraw_burst")
      ExBanking.deposit("withdraw_burst", 100, "EUR")

      results =
        1..100
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.withdraw("withdraw_burst", 1, "EUR") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 != {:error, :too_many_requests_to_user})) == 10
      assert {:ok, 90.0} = ExBanking.get_balance("withdraw_burst", "EUR")
    end
  end

  describe "get_balance/2" do
    test "should return {:error, :wrong_arguments} when user argument is non binary" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance(1, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.get_balance(1.15, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.get_balance(:atom, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.get_balance(%{}, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.get_balance({}, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.get_balance(nil, "EUR")
    end

    test "should return {:error, :wrong_arguments} when currency argument is non binary" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance("oscar", 1)
      assert {:error, :wrong_arguments} = ExBanking.get_balance("oscar", 1.15)
      assert {:error, :wrong_arguments} = ExBanking.get_balance("oscar", :atom)
      assert {:error, :wrong_arguments} = ExBanking.get_balance("oscar", %{})
      assert {:error, :wrong_arguments} = ExBanking.get_balance("oscar", {})
      assert {:error, :wrong_arguments} = ExBanking.get_balance("oscar", nil)
    end

    test "should return {:error, :user_does_not_exist} when user does not exists" do
      assert {:error, :user_does_not_exist} = ExBanking.get_balance("non_existence_user", "EUR")
    end

    test "should return balance with a precision of 2 decimal places" do
      ExBanking.create_user("user_1")
      ExBanking.deposit("user_1", 500.123, "EUR")
      assert {:ok, 500.12} = ExBanking.get_balance("user_1", "EUR")
    end

    test "should always down round the returned balance" do
      ExBanking.create_user("user_2")
      ExBanking.deposit("user_2", 500.129, "EUR")
      assert {:ok, 500.12} = ExBanking.get_balance("user_2", "EUR")
    end

    test "should return 0 when user does not have an account with the related currency" do
      ExBanking.create_user("abc")
      assert {:ok, 0.0} = ExBanking.get_balance("abc", "EUR")
    end

    test "should be able to process no more than 10 get balance operation at the same time for a single user" do
      ExBanking.create_user("user_3")

      results =
        1..15
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.get_balance("user_3", "EUR") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 == {:error, :too_many_requests_to_user})) == 5
    end

    test "should be able to processs get balance operation for different users at the same time" do
      ExBanking.create_user("user_4")
      ExBanking.create_user("user_5")

      results =
        for user <- ["user_4", "user_5"], i <- 1..15 do
          {user, i}
        end
        |> Enum.map(fn {user, _i} ->
          Task.async(fn -> ExBanking.get_balance(user, "EUR") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 == {:error, :too_many_requests_to_user})) == 10
    end

    test "should be able to withstand burst request" do
      ExBanking.create_user("get_balance_burst")

      results =
        1..100
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.get_balance("get_balance_burst", "EUR") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 != {:error, :too_many_requests_to_user})) == 10
    end
  end

  describe "send/4" do
    test "should return {:error, :wrong_arguments} when from_user argument is non binary" do
      assert {:error, :wrong_arguments} = ExBanking.send(1, "to_user", 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send(1.15, "to_user", 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send(:atom, "to_user", 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send(%{}, "to_user", 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send({}, "to_user", 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send(nil, "to_user", 500.123, "EUR")
    end

    test "should return {:error, :wrong_arguments} when to_user argument is non binary" do
      ExBanking.create_user("from_user_1")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_1", 1, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_1", 1.15, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_1", :atom, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_1", %{}, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_1", {}, 500.123, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_1", nil, 500.123, "EUR")
    end

    test "should return {:error, :wrong_arguments} when amount argument is non number" do
      ExBanking.create_user("from_user_2")
      ExBanking.create_user("to_user_2")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_2", "to_user_2", "500", "EUR")

      assert {:error, :wrong_arguments} =
               ExBanking.send("from_user_2", "to_user_2", "500.123", "EUR")

      assert {:error, :wrong_arguments} = ExBanking.send("from_user_2", "to_user_2", :atom, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_2", "to_user_2", %{}, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_2", "to_user_2", {}, "EUR")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_2", "to_user_2", nil, "EUR")
    end

    test "should return {:error, :wrong_arguments} when currency argument is non binary" do
      ExBanking.create_user("from_user_3")
      ExBanking.create_user("to_user_3")
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_3", "to_user_3", 500.123, 1)

      assert {:error, :wrong_arguments} =
               ExBanking.send("from_user_3", "to_user_3", 500.123, 1.15)

      assert {:error, :wrong_arguments} =
               ExBanking.send("from_user_3", "to_user_3", 500.123, :atom)

      assert {:error, :wrong_arguments} = ExBanking.send("from_user_3", "to_user_3", 500.123, %{})
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_3", "to_user_3", 500.123, {})
      assert {:error, :wrong_arguments} = ExBanking.send("from_user_3", "to_user_3", 500.123, nil)
    end

    test "should return {:error, :sender_does_not_exist} when sender does not exists" do
      assert {:error, :sender_does_not_exist} =
               ExBanking.send("non_existence_sender", "receiver", 500.123, "EUR")
    end

    test "should return {:error, :receiver_does_not_exist} when receiver does not exists" do
      ExBanking.create_user("from_user_4")

      assert {:error, :receiver_does_not_exist} =
               ExBanking.send("from_user_4", "non_existence_receiver", 500.123, "EUR")
    end

    test "should return {:error, :not_enough_money} when sender does not have anough balance" do
      ExBanking.create_user("from_user_5")
      ExBanking.create_user("to_user_5")
      ExBanking.deposit("from_user_5", 500, "EUR")

      assert {:error, :not_enough_money} = ExBanking.send("from_user_5", "to_user_5", 1000, "EUR")
    end

    test "should return {:error, :not_enough_money} when sender does not have and account with related currency" do
      ExBanking.create_user("from_user_6")
      ExBanking.create_user("to_user_6")

      assert {:error, :not_enough_money} = ExBanking.send("from_user_6", "to_user_6", 1000, "USD")
    end

    test "should be able to send 0 amount" do
      ExBanking.create_user("from_user_0")
      ExBanking.create_user("to_user_0")
      ExBanking.deposit("from_user_0", 1000, "EUR")
      assert {:ok, 1000.0, 0.0} = ExBanking.send("from_user_0", "to_user_0", 0, "EUR")
    end

    test "should be able to send 0 amount even if the sender account does not exist yet" do
      ExBanking.create_user("from_user_0a")
      ExBanking.create_user("to_user_0a")
      assert {:ok, 0.0, 0.0} = ExBanking.send("from_user_0a", "to_user_0a", 0, "EUR")
    end

    test "should return {:error, :too_many_requests_to_sender} if sender has more than 10 send request at the same time" do
      ExBanking.create_user("sender_1a")
      ExBanking.deposit("sender_1a", 50, "EUR")
      ExBanking.create_user("receiver_1a")
      ExBanking.create_user("receiver_2a")

      results =
        for receiver <- ["receiver_1a", "receiver_2a"], _ <- 1..10 do
          receiver
        end
        |> Enum.map(fn receiver ->
          Task.async(fn -> ExBanking.send("sender_1a", receiver, 1, "EUR") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 == {:error, :too_many_requests_to_sender})) == 10
      assert {:ok, 40.0} = ExBanking.get_balance("sender_1a", "EUR")
    end

    test "should return {:error, :too_many_requests_to_receiver} if receiver has more than 10 send request at the same time" do
      ExBanking.create_user("sender_1b")
      ExBanking.deposit("sender_1b", 50, "EUR")
      ExBanking.create_user("sender_2b")
      ExBanking.deposit("sender_2b", 50, "EUR")
      ExBanking.create_user("receiver_1b")

      results =
        for sender <- ["sender_1b", "sender_2b"], _ <- 1..10 do
          sender
        end
        |> Enum.map(fn sender ->
          Task.async(fn -> ExBanking.send(sender, "receiver_1b", 1, "EUR") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 == {:error, :too_many_requests_to_receiver})) == 10
      assert {:ok, 10.0} = ExBanking.get_balance("receiver_1b", "EUR")
    end

    test "should be able to withstand burst request" do
      ExBanking.create_user("sender_1a_burst")
      ExBanking.deposit("sender_1a_burst", 50, "EUR")
      ExBanking.create_user("receiver_1a")
      ExBanking.create_user("receiver_2a")

      results =
        for receiver <- ["receiver_1a", "receiver_2a"], _ <- 1..10 do
          receiver
        end
        |> Enum.map(fn receiver ->
          Task.async(fn -> ExBanking.send("sender_1a_burst", receiver, 1, "EUR") end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.count(results, &(&1 != {:error, :too_many_requests_to_sender})) == 10
      assert {:ok, 40.0} = ExBanking.get_balance("sender_1a_burst", "EUR")
    end
  end
end
