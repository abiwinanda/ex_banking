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
