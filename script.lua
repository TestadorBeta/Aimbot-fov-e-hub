local fov = 80
local maxTransparency = 0.7 -- Transparência máxima dentro do círculo (0.7 = 70% de transparência, mais visível)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Cam = game.Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local FOVring = Drawing.new("Circle")
FOVring.Visible = true
FOVring.Thickness = 2
FOVring.Color = Color3.fromRGB(128, 0, 128) -- Cor roxa
FOVring.Filled = true -- Preenchido para destacar, mas transparente
FOVring.Radius = fov
FOVring.Position = Cam.ViewportSize / 2
FOVring.Transparency = 0.5 -- Define a transparência inicial do círculo

local isFOVActive = true -- Controle para ativar/desativar o FOV
local isMobile = UserInputService.TouchEnabled -- Detecta se o dispositivo é mobile

-- Função para alternar o FOV
local function toggleFOV()
    isFOVActive = not isFOVActive
    FOVring.Visible = isFOVActive
end

-- Função para atualizar a posição do círculo
local function updateDrawings()
    local camViewportSize = Cam.ViewportSize
    FOVring.Position = camViewportSize / 2
end

-- Sistema de wall check
local function isVisible(targetPart)
    local origin = Cam.CFrame.Position
    local direction = (targetPart.Position - origin).Unit
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character or nil}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local result = workspace:Raycast(origin, direction * 500, raycastParams)
    if result and result.Instance then
        return result.Instance:IsDescendantOf(targetPart.Parent)
    end
    return true
end

-- Função principal para atualização do FOV
local function updateFOV()
    if not isFOVActive then return end
    updateDrawings()
    local closest = getClosestPlayerInFOV("Head")
    if closest and closest.Character:FindFirstChild("Head") then
        if isVisible(closest.Character.Head) then
            lookAt(closest.Character.Head.Position)
        end
    end

    if closest then
        local ePos, isVisible = Cam:WorldToViewportPoint(closest.Character.Head.Position)
        local distance = (Vector2.new(ePos.x, ePos.y) - (Cam.ViewportSize / 2)).Magnitude
        FOVring.Transparency = calculateTransparency(distance)
    else
        FOVring.Transparency = maxTransparency
    end
end

-- Ajustar mira para o jogador mais próximo
local function lookAt(target)
    local lookVector = (target - Cam.CFrame.Position).unit
    local newCFrame = CFrame.new(Cam.CFrame.Position, Cam.CFrame.Position + lookVector)
    Cam.CFrame = newCFrame
end

-- Calcular transparência do círculo com base na distância
local function calculateTransparency(distance)
    local maxDistance = fov
    local transparency = (1 - (distance / maxDistance)) * maxTransparency
    return transparency
end

-- Encontrar jogador mais próximo dentro do FOV
local function getClosestPlayerInFOV(trg_part)
    local nearest = nil
    local last = math.huge
    local playerMousePos = Cam.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local part = player.Character and player.Character:FindFirstChild(trg_part)
            if part and isVisible(part) then
                local ePos, isVisible = Cam:WorldToViewportPoint(part.Position)
                local distance = (Vector2.new(ePos.x, ePos.y) - playerMousePos).Magnitude

                if distance < last and isVisible and distance < fov then
                    last = distance
                    nearest = player
                end
            end
        end
    end

    return nearest
end

-- Adicionar botão móvel para dispositivos móveis
if isMobile then
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Parent = game.CoreGui
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 150, 0, 50)
    button.Position = UDim2.new(0.1, 0, 0.9, -60)
    button.Text = "Toggle FOV"
    button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    button.BackgroundTransparency = 0.3
    button.TextColor3 = Color3.new(1, 1, 1)
    button.BorderSizePixel = 2
    button.Parent = ScreenGui

    -- Permitir que o botão seja movido
    local dragging = false
    local dragInput, dragStart, startPos

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = button.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    button.MouseButton1Click:Connect(function()
        toggleFOV()
    end)
else
    -- Mostra notificação para dispositivos PC
    game.StarterGui:SetCore("SendNotification", {
        Title = "FOV Script",
        Text = "Pressione a tecla F para ativar/desativar o FOV.",
        Duration = 10
    })

    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.F then
            toggleFOV()
        end
    end)
end

-- Inicializa o loop de renderização
RunService.RenderStepped:Connect(updateFOV)