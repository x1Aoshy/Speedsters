local fs=require('@lune/fs')
for _,world in {'World1','World2'} do
 for _,name in {'NewWorld1ManualStagePads','World2ManualStagePads','WinPads'} do
  local path='audit/merged/'..world..'/ServerScriptService/Gameplay/'..name..'.luau'
  if not fs.isFile(path) then continue end
  local s=fs.readFile(path)
  local a=s:find('MarketplaceService.PromptProductPurchaseFinished:Connect(',1,true)
  if a then
   local b=s:find('\nend)',a,true);assert(b)
   s=s:sub(1,a-1)..'-- Developer-product ownership is granted only by ProcessReceipt.\n'..s:sub(b+5)
  end
  if name=='NewWorld1ManualStagePads' then
   local first=s:find('local function checkPendingDoubleWins(player)',1,true)
   local last=s:find('MarketplaceService.PromptGamePassPurchaseFinished',first,true)
   s=s:sub(1,first-1)..'local function checkPendingDoubleWins(player)\n\t-- Buying unlocks x2; touch the pad again to claim through RewardPadClaims.\n\t-- A delayed purchase cannot bypass distance, return, or transaction checks.\n\tplayer:SetAttribute("PendingDoubleWinsStage", nil)\n\tplayer:SetAttribute("PendingDoubleWinsIsFinal", nil)\nend\n\n'..s:sub(last)
  end
  fs.writeFile(path,s)
 end
end
print('Removed prompt-completion grants and unguarded delayed pad reward')
