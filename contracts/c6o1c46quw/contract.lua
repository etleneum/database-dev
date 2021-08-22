local shareprice = 1000 * 100 -- 100 sat
local complainprice = 1000 * 5000 -- 5000 sat
local supreme_admin = 'as8233vqxk' -- 'ay81i7dw7' -- fiatjaf@lntxbot
local one_week = 60 * 5 -- 60 * 60 * 24 * 7

function __init__ ()
  return {
    open = {},
    closed = {},
    open_complaints = {}
  }
end

function createmarket ()
  local factor = tonumber(call.payload.factor) or 0.02
  local creator = account.id or 'anonymous'
  local date_match = call.payload.date:gmatch('(%d+)') -- should be in YYYY-MM-DD format
  local date = os.time({
    year = tonumber(date_match()),
    month = tonumber(date_match()),
    day = tonumber(date_match()),
    hour = 23,
    minute = 59,
    second = 59,
  })
  local market = {
    factor = factor,
    terms = call.payload.terms,
    date = date,
    balance = _balance(factor, 1, 1),
    shares = {
      yes = { [creator] = 1 },
      no = { [creator] = 1 }
    },
    votes = {},
    created = os.time(),
    lastexchange = nil,
    nexchanges = 0,
  }

  local initial_deposit = call.msatoshi
  if initial_deposit ~= market.balance then
    error("initial deposit must be " .. market.balance .. " msat.")
  end

  if market.factor < 0 or market.factor > 1 then
    error("invalid factor " .. market.factor)
  end
  if market.terms:len() > 400 then
    error("invalid terms, too long: " .. market.terms)
  end
  if market.terms:len() < 40 then
    error("invalid terms, too short: " .. market.terms)
  end
  if market.date < market.created then
    error("invalid date in the past: " .. market.date)
  end
  if market.date > (market.created + 60 * 60 * 24 * 700) then
    error("invalid date too far in the future: " .. market.date)
  end

  contract.state.open[util.cuid()] = market
end

function exchange ()
  if not account.id then
    error('must be authenticated!')
  end

  local id = call.payload.id
  local market = contract.state.open[id]
  if not market then
    error('market not found!')
  end

  local side = call.payload.side
  if side ~= 'yes' and side ~= 'no' then
    error('side must be yes or no.')
  end

  -- trading can happen up to one week after the event date
  if os.time() > (market.date + one_week) then
    error('trading has finished for this market.')
  end

  -- shares can be negative, means selling
  local nshares = tonumber(call.payload.nshares)

  -- get shares for this user
  market.shares[side][account.id] = market.shares[side][account.id] or 0
  market.shares[side][account.id] = market.shares[side][account.id] + nshares

  if market.shares[side][account.id] < 0 then
    error("can't sell more shares than you currently own!")
  end

  local total_yes_shares = _countshares(market.shares['yes'])
  local total_no_shares = _countshares(market.shares['no'])

  if total_yes_shares == 0 or total_no_shares == 0 then
    error("total shares can't go to zero!")
  end

  local newbalance = _balance(
    market.factor,
    total_yes_shares,
    total_no_shares
  )
  local balancediff = newbalance - market.balance
  if balancediff > 0 then
    -- buying stuff, require payment.
    if call.msatoshi ~= balancediff then
      error("must include " .. balancediff .. "msat for this call.")
    end
  else
    -- selling stuff. send payment to this account.
    contract.send(account.id, -balancediff)
  end

  -- cleanup user account if share count is zero
  if market.shares[side][account.id] == 0 then
    market.shares[side][account.id] = nil
  end

  market.balance = newbalance
  market.lastexchange = os.time()
  market.nexchanges = market.nexchanges + 1
end

function complain ()
  -- if someone spots a market that is resolving to the wrong side, they can request
  -- a revision from the supreme admin
  local id = call.payload.id
  local market = contract.state.open[id]

  if not market then
    error('market ' .. id .. ' does not exist')
  end
  if (market.date + one_week) > os.time() then
    error('trading still ongoing for this market')
  end
  if call.msatoshi < complainprice then
    error('complaints must include a conditional payment of ' .. complainprice .. 'msat')
  end

  contract.state.open_complaints[id] = {
    msatoshi = call.msatoshi,
    complainer = account.id,
  }

  util.print("complaint registered for " .. id)
end

function bump ()
  local had_effect = false

  -- check all markets, resolve the ones that...
  for id, market in pairs(contract.state.open) do
    -- ...are expired (three weeks after the event),
    if (market.date + one_week * 3) < os.time() then
      -- unless there are pending complaints.
      if (not contract.state.open_complaints[id]) then
        -- resolving:
        local winning_side = _getwinningsidefromsharecount(market)
        if winning_side then
          _resolve(id, winning_side)
          had_effect = true
        else
          util.print("can't resolve " .. id .. ", number of shares is equal.")
        end
      end
    end
  end

  if not had_effect then
    error('this call did nothing')
  end
end

function forceresolve ()
  -- a supreme admin adjucating a disputed market
  if account.id ~= supreme_admin then
    error('must be supreme admin!')
  end

  local id = call.payload.id
  local market = contract.state.open[id]
  if not market then
    error('market not found!')
  end

  local resolution = call.payload.resolution
  if resolution ~= 'yes' and resolution ~= 'no' then
    error("resolution must be either yes or no.")
  end

  -- remove this complaint if it exists
  -- and refund the complainer if he did well
  local complaint = contract.state.open_complaints[id]
  if complaint then
    contract.state.open_complaints[id] = nil
    local winning_side = _getwinningsidefromsharecount(market)
    if winning_side == resolution or not complaint.complainer then
      -- complainer shouldn't have complained, gets penalized
      contract.send(supreme_admin, complaint.msatoshi)
    else
      -- complainer did well in complaining, gets their money back
      contract.send(complaint.complainer, complaint.msatoshi)
    end
  end

  -- resolve
  _resolve(id, resolution)
end

function _balance (factor, yes_shares, no_shares)
  local b = factor * (yes_shares + no_shares)
  local vshares = b * math.log(
    math.exp(yes_shares / b) + math.exp(no_shares / b)
  )
  return math.ceil(vshares * shareprice)
end

function _getwinningsidefromsharecount (market)
  local yes = _countshares(market.shares.yes)
  local no = _countshares(market.shares.no)
  if yes > no then
    return 'yes'
  elseif no > yes then
    return 'no'
  end
  return nil
end

function _countshares (shares)
  local nshares = 0
  for _, n in pairs(shares) do
    nshares = nshares + n
  end
  return nshares
end

function _resolve (id, side)
  util.print("market " .. id .. " resolved: " .. side)

  local market = contract.state.open[id]
  local remainder = market.balance

  -- paying shareholders
  for acct, n in pairs(market.shares[side]) do
    local msatoshi = n * shareprice
    contract.send(acct, msatoshi)
    remainder = remainder - msatoshi
  end

  -- archiving market
  contract.state.closed[id] = market
  contract.state.open[id] = nil
end