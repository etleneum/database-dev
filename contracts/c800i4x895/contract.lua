function __init__ ()
  return {}
end

function give ()
  contract.send('02bfcc528f7782f00722f8f9e1e262c409d528b4149d57640e550f6d6c06b8443e', call.msatoshi)
end