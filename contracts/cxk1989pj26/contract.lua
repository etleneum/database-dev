function __init__ ()
  return {}
end

function create_auction ()
  if not account.id then
    error('must be authenticated!')
  end

  local auction = {
    auction_item = call.payload.auction_item,
    creator_id = account.id,
    current_top_bid = tonumber(call.payload.starting_bid),
    min_step = tonumber(call.payload.min_step),    
    top_bider_id = account.id,
    end_datetime = os.time() + tonumber(call.payload.auction_duration_days) * 86400
  }
  contract.state[util.cuid()] = auction
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

    contract.send(contract.state[auction_id].creator_id, contract.state[auction_id].current_top_bid)
end