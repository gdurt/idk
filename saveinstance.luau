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

-- 2. Streaming Logic
local function StreamMap(bar)
    local LocalPlayer = game:GetService("Players").LocalPlayer
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local Origin = LocalPlayer.Character.HumanoidRootPart.CFrame
    local Radius = 1024
    local Size = 5000 
    
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
    
    -- 1. Prepass (Decompilation)
    if Options.DecompilePrepass then
        print("[SaveInstance] Running optimized prepass...")
        -- (Prepass logic remains the same)
        -- ...
    end
    
    -- 2. Streaming (This ensures Terrain is populated in the Workspace)
    if Options.SetStreaming then
        print("[SaveInstance] Streaming map to populate Terrain...")
        StreamMap(bar)
    end
    
    -- 3. Save
    print("[SaveInstance] Saving instance...")
    bar:Remove()
    local USSI = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/saveinstance.luau", true))()
    
    -- Ensure Terrain is included in the save options
    Options.IncludeTerrain = true 
    
    return USSI(Options)
end
