function __init__ ()
  return {}
end

function dosomething ()
  if call.msatoshi < 10000 then
    error('pay more!')
  end
  res = http.getjson("https://blockchain.info/ticker")
  util.print(res["USD"])
  contract.state.something = call.payload.something
end