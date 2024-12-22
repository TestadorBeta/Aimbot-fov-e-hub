local fov = 80
local maxTransparency = 0.7 -- Transparência máxima dentro do círculo (0.7 = 70%)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Cam = game.Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local FOVring = Drawing.new("Circle")
FOVring.Visible = true
FOVring.Thickness = 2
FOVring.Color = Color3.fromRGB(128, 0, 128) -- Cor roxa
FOVring.Filled = true
FOVring.Radius = fov
FOVring.Position = Cam.ViewportSize / 2
FOVring.Transparency = 0.5 -- Define a transparência inicial

local isFOVActive = true
local isMobile = UserInputService.TouchEnabled -- Detecta dispositivos móveis
local isTeamGame = false -- Inicialmente, não sabemos se é partida com equipes

-- Alternar visibilidade do FOV
local function toggleFOV()
    isFOVActive = not isFOVActive
    FOVring.Visible = isFOVActive
end

-- Atualizar posição do círculo
local function updateDrawings()
    local camViewportSize = Cam.ViewportSize
    FOVring.Position = camViewportSize / 2
end

-- Wall check para garantir que o alvo é visível
local function isVisible(targetPart)
    local origin = Cam.CFrame.Position
    local direction = (targetPart.Position - origin).Unit
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local result = workspace:Raycast(origin, direction * 500, raycastParams)
    if result and result.Instance then
        return result.Instance:IsDescendantOf(targetPart.Parent)
    end
    return true
end

-- Calcular transparência com base na distância
local function calculateTransparency(distance)
    local maxDistance = fov
    local transparency = (1 - (distance / maxDistance)) * maxTransparency
    return transparency
end

-- Detectar se é uma partida com equipes
local function detectTeamGame()
    local teamsExist = #Teams:GetTeams() > 0
    local newMode = teamsExist
    if newMode ~= isTeamGame then
        isTeamGame = newMode
        local notificationText = isTeamGame and "Modo de equipes detectado. Aimbot ajustado para mirar apenas em inimigos." or "Modo livre detectado. Aimbot ajustado para todos os jogadores."
        game.StarterGui:SetCore("SendNotification", {
            Title = "Modo de Jogo Alterado",
            Text = notificationText,
            Duration = 5
        })
    end
end

-- Encontrar jogador mais próximo no FOV
local function getClosestPlayerInFOV(trg_part)
    local nearest = nil
    local lastDistance = math.huge
    local playerMousePos = Cam.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isEnemy = not isTeamGame or (player.Team ~= LocalPlayer.Team)
            if isEnemy then
                local part = player.Character and player.Character:FindFirstChild(trg_part)
                if part and isVisible(part) then
                    local ePos, isVisible = Cam:WorldToViewportPoint(part.Position)
                    local distance = (Vector2.new(ePos.X, ePos.Y) - playerMousePos).Magnitude

                    if isVisible and distance < fov and distance < lastDistance then
                        lastDistance = distance
                        nearest = player
                    end
                end
            end
        end
    end
    return nearest
end

-- Ajustar câmera para mirar no alvo
local function lookAt(target)
    local lookVector = (target - Cam.CFrame.Position).Unit
    Cam.CFrame = CFrame.new(Cam.CFrame.Position, Cam.CFrame.Position + lookVector)
end

-- Atualizar FOV e mira
local function updateFOV()
    if not isFOVActive then return end
    updateDrawings()
    
    local closest = getClosestPlayerInFOV("Head")
    if closest and closest.Character:FindFirstChild("Head") then
        local head = closest.Character.Head
        if isVisible(head) then
            lookAt(head.Position)
        end
    end
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
    game.StarterGui:SetCore("SendNotification", {
        Title = "FOV Script",
        Text = "Pressione F para ativar/desativar o FOV.",
        Duration = 10
    })

    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.F then
            toggleFOV()
        end
    end)
end

-- Verificar modo de jogo a cada 1 minuto
detectTeamGame() -- Primeira verificação
task.spawn(function()
    while true do
        task.wait(60) -- Espera 1 minuto
        detectTeamGame()
    end
end)

-- Iniciar loop de atualização
RunService.RenderStepped:Connect(updateFOV)
