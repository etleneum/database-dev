function __init__ ()
  return {}
end

function dosomething ()
  if call.msatoshi < 10000 then
    error('pay more!')
  end
  res = http.gettext("https://www.blockchain.info/tobtc?currency=USD&value=1")
  utils.print(res)
  contract.state.something = call.payload.something
end