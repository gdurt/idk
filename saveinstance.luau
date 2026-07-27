--[=[
    Integrated Library: Streaming + Terrain + PrePass + USSI
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- 1. Terrain Capture
local function to_base64(data)
    if not data or #data == 0 then return "" end
    local b64_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result, bit_table = {}, {}
    for i = 1, #data do
        local byte = data:byte(i)
        local bits = {}
        for j = 7, 0, -1 do bits[#bits + 1] = (math.floor(byte / (2 ^ j)) % 2 == 1) and '1' or '0' end
        bit_table[#bit_table + 1] = table.concat(bits)
    end
    local bit_string = table.concat(bit_table)
    bit_string = bit_string .. string.rep('0', (6 - #bit_string % 6) % 6)
    for i = 1, #bit_string, 6 do
        local chunk = bit_string:sub(i, i + 5)
        local index = tonumber(chunk, 2) + 1
        result[#result + 1] = b64_chars:sub(index, index)
    end
    local padding = (#data % 3 == 1 and '==') or (#data % 3 == 2 and '=' or '')
    return table.concat(result) .. padding
end

local function CaptureTerrain()
    local Terrain = workspace:FindFirstChild("Terrain")
    if not Terrain then return end
    local ok, smooth = pcall(function() return gethiddenproperty(Terrain, "SmoothGrid") end)
    local ok2, physics = pcall(function() return gethiddenproperty(Terrain, "PhysicsGrid") end)
    if ok and ok2 then
        getgenv().smoothgrid = to_base64(smooth)
        getgenv().physicsgrid = to_base64(physics)
    end
    local ok3, matColors = pcall(function() return Terrain.MaterialColors end)
    if ok3 then getgenv().materialcolors = matColors end
end

-- 2. Streaming Logic (The "Streamer" core)
local function StreamMap()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local Origin = LocalPlayer.Character.HumanoidRootPart.CFrame
    local Radius = 1024
    local Size = 5000 -- Adjust this based on map size
    
    for x = -Size, Size, Radius do
        for z = -Size, Size, Radius do
            local Pos = Vector3.new(x, Origin.Y, z)
            LocalPlayer:RequestStreamAroundAsync(Pos, 20)
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(Pos)
            task.wait(0.2)
        end
    end
    LocalPlayer.Character.HumanoidRootPart.CFrame = Origin
end

-- 3. Main Library Function
return function(Options)
    Options = Options or {}
    
    -- A) Stream Map if requested
    if Options.SetStreaming then
        print("[SaveInstance] Streaming map...")
        StreamMap()
    end
    
    -- B) Capture Terrain
    print("[SaveInstance] Capturing terrain...")
    CaptureTerrain()
    
    -- C) Prepass
    if Options.DecompilePrepass then
        print("[SaveInstance] Running prepass...")
        local Cache = {}
        local function DecompileViaAPI(Bc)
            local Ok, Res = pcall(request or http_request, {
                Url = "https://api.lua.expert/decompile",
                Method = "POST",
                Headers = { ["content-type"] = "application/json" },
                Body = game:GetService("HttpService"):JSONEncode({ script = (base64_encode or function(d) return d end)(Bc) }),
            })
            return Ok and Res.StatusCode == 200, Ok and Res.Body or "failed"
        end
        
        getgenv().decompile = function(Scr)
            local Ok, Bc = pcall(getscriptbytecode, Scr)
            if Ok and Cache[Bc] then return Cache[Bc] end
            return (getgenv().decompile and getgenv().decompile(Scr)) or "-- failed"
        end
        
        for _, o in next, game:GetDescendants() do
            if o:IsA("LuaSourceContainer") then
                local Ok, Bc = pcall(getscriptbytecode, o)
                if Ok and type(Bc) == "string" and Bc ~= "" and not Cache[Bc] then
                    task.spawn(function()
                        local Success, Body = DecompileViaAPI(Bc)
                        if Success then Cache[Bc] = Body end
                    end)
                end
            end
        end
    end
    
    -- D) Save Instance
    print("[SaveInstance] Saving...")
    local USSI = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/saveinstance.luau", true))()
    return USSI(Options)
end
