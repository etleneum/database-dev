-- https://teletype.in/@hypecoinnews/bitcoin-derivatives

--[[
    simple contract for puts and calls
    https://blockchain.info/tobtc?currency=USD&value=1
    
]]

function __init__ ()
   return {
      fee=1000,
      offers={_=0},
      calls={_=0},
      puts={_=0},
      expired={_=0},
      redeemed={_=0}
      
   }
end

function mint_call()
  if not account.id then
    error('must be authenticated!')
  end 
  local new_id = util.cuid()
  util.print(new_id)

  -- check oracle and record price
  -- {"15m":63264.2,"buy":63264.2,"last":63264.2,"sell":63264.2,"symbol":"USD"} 
  price = http.getjson("https://blockchain.info/ticker")
  util.print(price["USD"]["15m"])

  local strike = tonumber(call.payload.strike)*1000
  local volume = tonumber(call.payload.volume)*1000
  local premium = tonumber(call.payload.premium)*1000

  local new_call = {
    seller = account.id,
    premuim = premium,
    strike = strike,    
    volume = volume,        
    expiration = os.time() + tonumber(call.payload.duration) * 86400,
    mint_price = tonumber(price["USD"]["15m"]),
    owner = 'offer'
  }
  contract.state[new_id] = auction
  contract.send(contract.id, volume*(strike+premium))  
  -- 032c712b860caeeaf72e2524011efa1ba936e837efac27b1d9afe7eb57ffcd4875
  local fee = math.ceil(volume/10000)
  contract.send('032c712b860caeeaf72e2524011efa1ba936e837efac27b1d9afe7eb57ffcd4875', fee)
end