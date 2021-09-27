function __init__ ()
  return {}
end

function create_auction ()
  local auction = {
    creator_id = account.id,
    current_top_bid = tonumber(call.payload.starting_bid),
    top_bider_id = account.id,
    end_datetime = os.time() + tonumber(call.payload.auction_duration_days) * 86400
  }
  contract.state[util.cuid()] = auction
end

function make_bet ()
    local auction_id = call.payload.auction_id
    local bid_amount = tonumber(call.msatoshi)
    
    if bid_amount < contract.state[auction_id].current_top_bid then
        error("you can only place bid higher then " .. contract.state[auction_id].current_top_bid .. " sats.")
    end
    
    if contract.state[auction_id].current_top_bid ~= 0 then
        contract.send(contract.state[auction_id].top_bider_id, contract.state[auction_id].current_top_bid)
    end
    
    if os.time() > contract.state[auction_id].end_datetime then
        error("this auction is finished")
    end
    
    contract.state[auction_id].current_top_bid = bid_amount
    contract.state[auction_id].top_bider_id = account.id
end

function finish_auction ()
    local auction_id = call.payload.auction_id
    
    if os.time() < contract.state[auction_id].end_datetime then
        error("this auction still not finished")
    end

    contract.send(contract.state[auction_id].creator_id, contract.state[auction_id].current_top_bid)
end