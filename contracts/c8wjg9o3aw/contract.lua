function __init__ ()
   return {
      closed={_=0}
   }
end

function create_auction ()
  if not account.id then
    error('must be authenticated!')
  end
  
  local new_id = util.cuid()
  util.print(new_id)
  
  local auction = {
    auction_item = call.payload.auction_item,
    creator_id = account.id,
    current_top_bid = tonumber(call.payload.starting_bid)*1000,
    min_step = tonumber(call.payload.min_step)*1000,    
    top_bider_id = account.id,
    end_datetime = os.time() + tonumber(call.payload.auction_duration_days) * 86400,
    state = true
  }
  
  contract.state[new_id] = auction  
end

function place_bid ()
    if not account.id then
        error('must be authenticated!')
    end
    
    local auction_id = call.payload.auction_id
    
    if os.time() > contract.state[auction_id].end_datetime then
        error("this auction is finished")
    end

    local new_bid = tonumber(call.msatoshi)
    top_bid = contract.state[auction_id].current_top_bid
    step = contract.state[auction_id].min_step
    
    if new_bid < top_bid + step then
        error("you can only place bid higher then " .. top_bid + step .. " sats.")
    end
    
    if top_bid ~= 0 then
        contract.send(contract.state[auction_id].top_bider_id, top_bid)
    end  
    
    contract.state[auction_id].current_top_bid = new_bid
    contract.state[auction_id].top_bider_id = account.id
end

function finish_auction ()
    local auction_id = call.payload.auction_id
    
    if os.time() < contract.state[auction_id].end_datetime then
        error("this auction still not finished")
    end

    if not contract.state[auction_id].state then
        error("auction is already finished")
    end
    
    contract.send(contract.state[auction_id].creator_id, contract.state[auction_id].current_top_bid)
    contract.state[auction_id].state = false
    contract.state["closed"][auction_id] = contract.state[auction_id]
    contract.state[auction_id] = nil
end

function deposit ()
  if not account.id then
    error('must be authenticated!')
  end

  contract.send(account.id, call.msatoshi)
end