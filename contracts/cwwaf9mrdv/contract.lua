function __init__ ()
  return {}
end

function topup ()
  contract.send(call.payload.receiver, call.msatoshi)
end
