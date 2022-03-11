function __init__ ()
  return {}
end

function register ()
    if not account.id then
        error('must be authorized')
    end
    
    local choices = 0
    local key = util.cuid()
    local title = call.payload.title
    local lifetime = tonumber(call.payload.lifetime) or 3600
    
    if type(title) ~= 'string' or utf8.len(title) < 1 then
        error('title missing')
    end
    
    if lifetime < 3600 then
        error('lifetime must be a number >= 3600')
    end
    
    -- required fields
    for i = 1, 2, 1 do
        local choice = call.payload['choice_' .. i]
        
        if type(choice) ~= 'string' or utf8.len(choice) < 1 then
            error('choice 1 & 2 missing')
        end
        
        choices = choices + 1
    end
    
    -- optional fields
    for i = 3, 4, 1 do
        local choice = call.payload['choice_' .. i]
        
        if type(choice) == 'string' and utf8.len(choice) >= 1 then
            choices = choices + 1
        end
    end
    
    local poll = {
        title = title,
        lifetime = lifetime,
        choice_1 = call.payload.choice_1,
        choice_2 = call.payload.choice_2,
        choice_3 = call.payload.choice_3,
        choice_4 = call.payload.choice_4,
        voters = {},
        choices = choices,
        owner = account.id,
        created = os.time(),
    }
    
    contract.state[key] = poll
end

function vote ()
    if not account.id then
        error('must be authorized')
    end
    
    local key = call.payload.key
    
    if type(key) ~= 'string' or utf8.len(key) < 1 then
        error('key missing')
    end
    
    local poll = contract.state[key]
    
    if not poll then
        error("key " .. key .. " doesn't not exist")
    end
    
    -- lifetime check
    if poll.created + poll.lifetime < os.time() then
        error('poll expired')
    end
    
    -- already voted?
    for _, v in ipairs(poll.voters) do
        if v == account.id then
            error('already voted')
        end
    end
    
    local choice = tonumber(call.payload.choice) or 0
    
    if choice < 1 or choice > poll.choices then
        error('choice must be a number >= 1 and <= ' .. poll.choices)
    end
    
    poll.voters[account.id] = choice
end