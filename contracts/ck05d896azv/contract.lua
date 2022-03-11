function __init__ ()
  return {}
end

function register ()
    if not account.id then
        error('must be authorized')
    end

    local voters = {}
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
    for _, v in ipairs({'choice_1', 'choice_2'}) do
        local choice = call.payload[v]
        
        if type(choice) ~= 'string' or utf8.len(choice) < 1 then
            error('choice 1 & 2 missing')
        end
        
        voters[v] = {}
    end
    
    -- optional fields
    for _, v in ipairs({'choice_3', 'choice_4'}) do
        local choice = call.payload[v]
        
        if type(choice) == 'string' and utf8.len(choice) >= 1 then
            voters[v] = {}
        end
    end
    
    local poll = {
        title = title,
        lifetime = lifetime,
        choice_1 = call.payload.choice_1,
        choice_2 = call.payload.choice_2,
        choice_3 = call.payload.choice_3,
        choice_4 = call.payload.choice_4,
        voters = voters,
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
        for _, vv in ipairs(v) do
            if vv == account.id then
                error('already voted')
            end
        end
    end
    
    local choice = tonumber(call.payload.choice)
    
    util.print('-> ' .. #poll.voters)
    
    if choice < 1 or choice > #poll.voters then
        error('choice must be a number >= 1 and <= ' .. #poll.voters)
    end
    
    local choice_prefixed = 'choice_' .. choice
    local choice_voters = poll.voters[choice_prefixed]
    
    poll.voters[choice_prefixed][#choice_voters + 1] = account.id
end