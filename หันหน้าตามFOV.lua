-- [[ 1. การตั้งค่า: Hard Lock + Prediction (หนึบระดับตายตัว + ดักหน้าขั้นบันได) ]]
local SETTINGS = {
    OFFSET_Y = -30,           -- จุดแดงและวงเล็งอยู่ที่แกน Y -30 ตามสั่งเป๊ะๆ
    OFFSET_X = 0,             
    FOV_RADIUS = 150,         
    AIM_SPEED = 1.0,          -- ความเร็ววาร์ปติดเป้า
    CORRECTION_VALUE = 10.2   
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- [[ 2. สร้าง Visuals (วงแดงและจุดแดง) ]]
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
local function CreateVisual(size, color, offset, isCircle)
    local f = Instance.new("Frame", ScreenGui)
    f.Size = size
    f.BackgroundColor3 = color
    f.Position = UDim2.new(0.5, SETTINGS.OFFSET_X, 0.5, offset)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    if isCircle then
        f.BackgroundTransparency = 1
        local Stroke = Instance.new("UIStroke", f)
        Stroke.Color = color
        Stroke.Thickness = 1.2
        Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    end
    return f
end

local RedPoint = CreateVisual(UDim2.new(0, 6, 0, 6), Color3.fromRGB(255, 0, 0), SETTINGS.OFFSET_Y, false)
local FOV_Ring = CreateVisual(UDim2.new(0, SETTINGS.FOV_RADIUS * 2, 0, SETTINGS.FOV_RADIUS * 2), Color3.fromRGB(255, 0, 0), SETTINGS.OFFSET_Y, true)

-- [[ 3. สร้างปุ่ม GUI (ขวาบน) ]]
local Toggle = Instance.new("TextButton", ScreenGui)
Toggle.Name = "HardLockToggle"
Toggle.Size = UDim2.new(0, 100, 0, 35) 
Toggle.Position = UDim2.new(0.85, 0, 0.05, 0) 
Toggle.Text = "HARD LOCK: OFF"
Toggle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
Toggle.Font = Enum.Font.SourceSansBold
Toggle.TextSize = 12 
Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", Toggle)
Stroke.Color = Color3.fromRGB(255, 0, 0)
Stroke.Thickness = 1.5

-- [[ ฟังก์ชันเสริม: ค้นหาชิ้นส่วน "ลำตัว" ของตัวละครเป้าหมายแบบเรียลไทม์ ]]
local function GetBodyTorso(Character)
    return Character:FindFirstChild("Torso") or 
           Character:FindFirstChild("UpperTorso") or 
           Character:FindFirstChild("LowerTorso") or 
           Character:FindFirstChild("HumanoidRootPart")
end

-- [[ 4. ระบบค้นหาเป้าหมาย (Hard Lock-On) ]]
local IsActive = false
local LockedTarget = nil 

Toggle.MouseButton1Click:Connect(function()
    IsActive = not IsActive
    if not IsActive then 
        LockedTarget = nil -- ล้างค่าเป้าหมายเมื่อปิด
    end
    Toggle.Text = IsActive and "HARD LOCK: ON" or "HARD LOCK: OFF"
    Toggle.BackgroundColor3 = IsActive and Color3.fromRGB(200, 0, 0) or Color3.fromRGB(30, 30, 30)
end)

local function GetTarget()
    local Camera = workspace.CurrentCamera
    local Center = Vector2.new(Camera.ViewportSize.X / 2 + SETTINGS.OFFSET_X, Camera.ViewportSize.Y / 2 + SETTINGS.OFFSET_Y)
    
    -- ส่วนเช็คเป้าหมายเดิม: ถ้ายังไม่ตาย ให้ล็อกค้างไว้ที่ชิ้นส่วนลำตัวคนเดิมตลอดกาล ไม่หลุดเป้า
    if LockedTarget then
        if LockedTarget.Parent and LockedTarget.Parent:FindFirstChild("Humanoid") and LockedTarget.Parent.Humanoid.Health > 0 then
            local LiveTorso = GetBodyTorso(LockedTarget.Parent)
            if LiveTorso then
                return LiveTorso
            end
        else
            LockedTarget = nil
        end
    end

    -- หาเป้าหมายใหม่ (จะทำงานเฉพาะตอนที่ยังไม่มีคนโดนล็อค)
    local NewTarget, MinDist = nil, SETTINGS.FOV_RADIUS
    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= game.Players.LocalPlayer and p.Character then
            local TorsoPart = GetBodyTorso(p.Character)
            if TorsoPart then
                local Hum = p.Character:FindFirstChild("Humanoid")
                if Hum and Hum.Health > 0 then
                    local Pos, OnScreen = Camera:WorldToViewportPoint(TorsoPart.Position)
                    if OnScreen then
                        local Dist = (Vector2.new(Pos.X, Pos.Y) - Center).Magnitude
                        if Dist < MinDist then
                            MinDist = Dist
                            NewTarget = TorsoPart
                        end
                    end
                end
            end
        end
    end
    
    LockedTarget = NewTarget
    return NewTarget
end

-- [[ ฟังก์ชันคำนวณตำแหน่งดักหน้าขั้นบันไดแบบ 3 มิติยึดตามลำตัว ]]
local function GetPredictedPosition(TargetPart)
    if not TargetPart or not TargetPart.Parent then return nil end
    
    local Char = LocalPlayer.Character
    local MyRoot = Char and Char:FindFirstChild("HumanoidRootPart")
    local TargetRoot = TargetPart.Parent:FindFirstChild("HumanoidRootPart") -- ใช้ความเร็วหลักจาก RootPart
    
    if MyRoot and TargetRoot then
        local targetVelocity = TargetRoot.Velocity
        local distance = (MyRoot.Position - TargetRoot.Position).Magnitude
        
        -- ปรับเวลาวินาทีการดักหน้าขั้นบันไดตามระยะห่างเป๊ะๆ
        local predictionTime = 0
        if distance < 100 then
            predictionTime = 0.2   -- ใกล้กว่า 100 สตัด ดักหน้า 0.2 วิ
        elseif distance >= 100 and distance <= 200 then
            predictionTime = 0.3   -- ช่วง 100 ถึง 200 สตัด ดักหน้า 0.3 วิ
        elseif distance > 200 then
            predictionTime = 0.6   -- ไกลกว่า 200 สตัดขึ้นไป ดักหน้า 0.6 วิ
        end
        
        -- นำตำแหน่งลำตัวปัจจุบัน (Real-time) มาคำนวณบวกทิศทางดักหน้าครบทุกแกน (X, Y, Z)
        local predictedPos = TargetPart.Position + (targetVelocity * predictionTime)
        return predictedPos
    end
    
    return TargetPart.Position
end

-- [[ 5. ระบบการล็อคแบบ Direct + หมุนกล้องดักหน้าล่วงหน้าเรียบลื่น ]]
RunService.RenderStepped:Connect(function()
    if IsActive then
        local Target = GetTarget()
        if Target then
            local Camera = workspace.CurrentCamera
            
            -- คำนวณพิกัดดักหน้าจากตำแหน่งลำตัวแบบ Real-time ทุกเฟรม
            local PredictedPos = GetPredictedPosition(Target)
            
            if PredictedPos then
                -- บังคับกล้องมองตรงไปที่ "ตำแหน่งดักหน้า" เพื่อให้สกิล/กระสุนพุ่งไปตัดหน้าเป้าหมายพอดี
                local LookAt = CFrame.lookAt(Camera.CFrame.Position, PredictedPos)
                local Correction = CFrame.Angles(math.rad(SETTINGS.OFFSET_Y / SETTINGS.CORRECTION_VALUE), 0, 0) 
                Camera.CFrame = LookAt * Correction
            end
        end
    end
end)
