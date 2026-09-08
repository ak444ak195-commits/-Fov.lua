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
