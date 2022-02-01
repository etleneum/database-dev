function __init__ ()
  return {}
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
    ticket_price = tonumber(call.payload.ticket_price)*1000,
    tickets_to_start = call.payload.tickets_to_start,
    tickets={_=0},
    lottery_fund=0,
    winner_id = '',
    auction_duration_days = tonumber(call.payload.auction_duration_days),
    end_datetime = 0,
    started = false,
    state = true
  }
  contract.state[new_id] = auction
end

function buy_ticket ()
    if not account.id then
        error('must be authenticated!')
    end

    local auction_info = contract.state[call.payload.auction_id]
    
    if os.time() > auction_info.end_datetime then
        error("this loto auction is finished")
    end

    local sats_paid = tonumber(call.msatoshi)
    ticket_price = auction_info.ticket_price
    
    if sats_paid < ticket_price then
        error("ticket price is " .. ticket_price .. " sats, please pay more")
    end

    for sats_amount = sats_paid,ticket_price,-ticket_price
    do 
        local ticket_id = util.cuid()
        auction_info.tickets[ticket_id] = account.id
        auction_info.lottery_fund = auction_info.lottery_fund + ticket_price
    end

    if auction_info.tickets_to_start <= #auction_info.tickets and not auction_info.started then
        auction_info.end_datetime = os.time() + auction_info.auction_duration_days * 86400
    end
end

function finish_loto_auction ()
    local auction_info = contract.state[call.payload.auction_id]
    
    if not auction_info.started then
        error("this loto auction still not started")
    end

    if os.time() < auction_info.end_datetime then
        error("this loto auction still not finished")
    end

    if not auction_info.state then
        error("loto auction is already finished")
    end
    
    local winner = auction_info.tickets[math.random(#auction_info.tickets)]
    auction_info.winner_id = winner
    contract.send(auction_info.creator_id, auction_info.lottery_fund)
    auction_info.state = false
end

function deposit ()
  if not account.id then
    error('must be authenticated!')
  end

  contract.send(account.id, call.msatoshi)
end