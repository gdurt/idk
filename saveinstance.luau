--[=[
    SaveInstance Library (Integrated Edition)
    With Progress Bar Integration
]=]

-- UI Helper: Create a simple drawing bar
local function CreateProgressBar()
    local bar = Drawing.new("Square")
    bar.Visible = false
    bar.Size = Vector2.new(400, 20)
    bar.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X/2 - 200, 50)
    bar.Color = Color3.fromRGB(0, 255, 0)
    bar.Filled = true
    bar.Transparency = 1
    return bar
end

-- 1. Terrain Extraction Logic
local b64_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function to_base64(data)
    if not data or #data == 0 then return "" end
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

-- 2. Streaming Logic
local function StreamMap(bar)
    local LocalPlayer = game:GetService("Players").LocalPlayer
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local Origin = LocalPlayer.Character.HumanoidRootPart.CFrame
    local Radius = 1024
    local Size = 5000 
    
    local xSteps = #{-Size, Size, Radius} -- Rough estimate for progress calculation
    local totalSteps = 25 -- Number of iterations in loop
    local currentStep = 0
    
    for x = -Size, Size, Radius do
        for z = -Size, Size, Radius do
            currentStep += 1
            local Pos = Vector3.new(x, Origin.Y, z)
            LocalPlayer:RequestStreamAroundAsync(Pos, 20)
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(Pos)
            
            -- Update Progress Bar
            if bar then
                bar.Size = Vector2.new((currentStep / totalSteps) * 400, 20)
            end
            
            task.wait(0.3)
        end
    end
    LocalPlayer.Character.HumanoidRootPart.CFrame = Origin
end

-- 3. Main Library Function
return function(Options)
    Options = Options or {}
    local bar = CreateProgressBar()
    bar.Visible = true
    
    -- 1. Prepass
    if Options.DecompilePrepass then
        print("[SaveInstance] Running optimized prepass...")
        local Cache = {}
        local UniqueScripts = {}
        for _, o in next, game:GetDescendants() do
            if o:IsA("LuaSourceContainer") then
                local Ok, Bc = pcall(getscriptbytecode, o)
                if Ok and type(Bc) == "string" and Bc ~= "" and not UniqueScripts[Bc] then
                    UniqueScripts[Bc] = true
                end
            end
        end

        local MaxConcurrent = 5
        local InFlight = 0
        local ScriptList = {}
        for Bc in next, UniqueScripts do table.insert(ScriptList, Bc) end
        local totalScripts = #ScriptList

        for i, Bc in ipairs(ScriptList) do
            while InFlight >= MaxConcurrent do task.wait(0.1) end
            InFlight += 1
            
            -- Update Bar
            bar.Size = Vector2.new((i / totalScripts) * 400, 20)
            
            task.spawn(function()
                local Ok, Res = pcall(request or http_request, {
                    Url = "https://api.lua.expert/decompile",
                    Method = "POST",
                    Headers = { ["content-type"] = "application/json" },
                    Body = game:GetService("HttpService"):JSONEncode({ script = (base64_encode or function(d) return d end)(Bc) }),
                })
                if Ok and Res.StatusCode == 200 then Cache[Bc] = Res.Body end
                InFlight -= 1
            end)
        end
        while InFlight > 0 do task.wait(0.1) end
        
        getgenv().decompile = function(Scr)
            local Ok, Bc = pcall(getscriptbytecode, Scr)
            if Ok and Cache[Bc] then return Cache[Bc] end
            return (getgenv().decompile and getgenv().decompile(Scr)) or "-- failed"
        end
    end
    
    -- 2. Terrain
    CaptureTerrain()
    
    -- 3. Streaming
    if Options.SetStreaming then
        StreamMap(bar)
    end
    
    -- 4. Save
    bar:Remove()
    local USSI = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/saveinstance.luau", true))()
    return USSI(Options)
end
