local fs=require('@lune/fs')
for _,world in {'World1','World2'} do
 local path='audit/merged/'..world..'/StarterGui/Messages/MessageHandler.luau'
 local s=fs.readFile(path)
 local at=assert(s:find('local function displayAnnouncement',1,true))
 s=s:sub(1,at-1)..[[local function escapeAnnouncementText(value)
	return (tostring(value):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&apos;"))
end

]]..s:sub(at)
 local old='senderName, messageText)';local a,b=s:find(old,1,true);assert(a)
 s=s:sub(1,a-1)..'escapeAnnouncementText(senderName), escapeAnnouncementText(messageText))'..s:sub(b+1)
 fs.writeFile(path,s)
end
