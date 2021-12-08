function __init__ ()
  return {}
end

function tipme ()
  contract.send('020b73b23976bd7dacf3ba5cd7f8d7412995a94afa243b4f9f7b6f321d428e2882', call.msatoshi)
  print('Thanks!')
end