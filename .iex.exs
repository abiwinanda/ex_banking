create_users = fn ->
  ["one", "two", "three", "four", "five"]
  |> Enum.map(fn user ->
    Task.async(fn -> ExBanking.create_user(user) end)
  end)
  |> Enum.map(&Task.await/1)
end

top_up_users_balance = fn ->
  ["one", "two", "three", "four", "five"]
  |> Enum.map(fn user ->
    Task.async(fn -> ExBanking.deposit(user, 10000.543 ,"EUR") end)
  end)
  |> Enum.map(&Task.await/1)
end

deposit_balance = fn ->
  1..20
  |> Enum.map(fn _ ->
      Task.async(fn -> ExBanking.deposit("one", 1 ,"EUR") end)
  end)
  |> Enum.map(&Task.await/1)
end

deposit_balance_with_different_currencies = fn ->
  1..20
  |> Enum.map(fn i ->
      Task.async(fn -> ExBanking.deposit("one", 1 ,"#{i}") end)
  end)
  |> Enum.map(&Task.await/1)
end

withdraw_balance = fn ->
  1..15
  |> Enum.map(fn _ ->
      Task.async(fn -> ExBanking.withdraw("one", 1 ,"EUR") end)
  end)
  |> Enum.map(&Task.await/1)
end

get_balance = fn ->
  1..15
  |> Enum.map(fn _ ->
      Task.async(fn -> ExBanking.get_balance("one", "EUR") end)
  end)
  |> Enum.map(&Task.await/1)
end
