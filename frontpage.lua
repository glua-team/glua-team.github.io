-- I can't bear to deal with javascript's bullshit so we're now using lua
-- code is kindof a mess because i don't want to split this into multiple files
-- don't touch/use anything except concommand.Add

js = require("js")

term = js.global.term

term:writeln("loaded lua vm!")

WEBCONSOLE_VERSION = "0.1.0"
local gluaLogo = [[
       _            _
  __ _| |_  _ __ _ | |_ ___ __ _ _ __
 / _` | | || / _` ||  _/ -_) _` | '  \
 \__, |_|\_,_\__,_(_)__\___\__,_|_|_|_|
 |___/

reverse, control, exploit

]]

local longestName = 0 -- used by pretty printer
local members = {}
local membersByName = {}

local prompt = "glua.team>> "
local linehistory = {}
local currentHistory = 0
local lrPos = 0
local tempLine = ""
local linebuffer = ""
local inputIsActive = true
local MAINTHREAD_RUNNING = false
local murderedCoroutines = {}

local function wait(msec)
    local thread = coroutine.running()
    js.global:setTimeout(function()
        if murderedCoroutines[thread] then return end
        if coroutine.status(thread) == "suspended" then
            coroutine.resume(thread)
        end
    end,msec)
    coroutine.yield()
end

local function clearInput()
    term:write((" "):rep(#linebuffer - lrPos))
    term:write(("\b \b"):rep(#linebuffer))
    linebuffer = ""
end

local function queryInput()
    MAINTHREAD_RUNNING = false
    local ans = coroutine.yield()
    MAINTHREAD_RUNNING = true
    linehistory[#linehistory + 1] = linebuffer
    currentHistory = #linehistory + 1
    tempLine = false
    lrPos = 0
    linebuffer = ""

    return ans
end

local function queryRaw(question)
    term:write(question)
    local ans = queryInput()
    return ans
end

local function clearWholeLine()
    term:write(("\b \b"):rep(255))
end

local function addMember(name,role,data)
    longestName = math.max(longestName,utf8.len(name))
    members[#members + 1] = {
        name = name:lower(),
        role = role,
        data = data,
    }
    membersByName[name:lower()] = members[#members]
end

local function shuffleTeam()
    local out = {}

    while #members > 0 do
        out[#out + 1] = table.remove(members,math.random(#members))
    end

    members = out
end

addMember("swadical","team lead",{
    steamID64 = "76561198137637055",
    twitter = "iamswadical",
    github = "SwadicalRag",
})
addMember("notcake","team lead",{
    steamID64 = "76561197998805249",
    github = "notcake",
})
addMember("meepen","team lead",{
    steamID64 = "76561198050165746",
    github = "meepdarknessmeep",
})

addMember("velkon","team assistant",{steamID64 = "76561198154133184"})
addMember("mcd1992","team assistant",{steamID64 = "76561197991350071"})

addMember("parakeet","ctf roster",{
    steamID64 = "76561197997945339",
    twitter = "cogg_rocks",
    github = "birdbrainswagtrain"
})
addMember("guurgle","ctf roster",{steamID64 = "76561198093185405",twitter = "iamguurgle"})
addMember("Ling","ctf roster",{steamID64 = "76561198044542936"})
addMember("GGG KILLER","ctf roster",{steamID64 = "76561198044403949",keybase = "gggkiller"})
addMember("Trixter","ctf roster",{steamID64 = "76561198109939061"})

addMember("Author.","friend",{steamID64 = "76561198076402038"})
addMember("aStonedPenguin","friend",{steamID64 = "76561198042764635"})
addMember("Bull","friend",{steamID64 = "76561198045139792"})
addMember("zerf","friend",{steamID64 = "76561198052589582"})
addMember("aria","friend",{steamID64 = "76561198199062669"})
addMember("metaman","friend",{steamID64 = "76561197999418456"})
addMember("lixquid","friend",{steamID64 = "76561198005961369"})
addMember("lenny.","friend",{steamID64 = "76561198021109934"})
addMember("PotcFdk","friend",{steamID64 = "76561198021245859"})
addMember("code_gs","friend",{steamID64 = "76561198026175948"})
addMember("orc","friend",{steamID64 = "76561198066396249"})
addMember("notsosuper","friend",{steamID64 = "76561198048132773"})
addMember("deagler","friend",{steamID64 = "76561198152808974"})
addMember("knoxed","friend",{steamID64 = "76561197994704078"})
addMember("mikey howell","friend",{steamID64 = "76561197983045206"})
addMember("ott","friend",{steamID64 = "76561198033321448"})
addMember("beast","friend",{steamID64 = "76561197964898382"})
addMember("Potatofactory","friend",{steamID64 = "76561198074240735"})
addMember("TFA","friend",{steamID64 = "76561198161775645"})
addMember("Tenrys","friend",{steamID64 = "76561198025218043"})
addMember("Footsies","friend",{steamID64 = "76561198106061489"})
addMember("ARitz Cracker","friend",{steamID64 = "76561197997486016"})
addMember("meharryp","friend",{steamID64 = "76561198071482825"})
addMember("Coment","friend",{steamID64 = "76561198014573560"})
addMember("Minty Fresh","friend",{steamID64 = "76561198004178530"})
addMember("Datamats","friend",{steamID64 = "76561198067350699"})
addMember("NootNootEh","friend",{steamID64 = "76561197960281616"})
addMember("LMM","friend",{steamID64 = "76561198141863800"})
addMember("dog = 💣","friend",{steamID64 = "76561198032705858"})
addMember("moat","friend",{steamID64 = "76561198053381832"})

concommand = {}
concommand.commands = {}

function concommand.Add(cmd,help,callback)
    concommand.commands[cmd] = {
        callback = callback,
        help = help or "No help/usage data found",
    }
end

function concommand.Run(str)
    local cmd,argStr = str:match("^([a-zA-Z0-9]*)%s*(.*)$")

    if concommand.commands[cmd] then
        local args,curArg = {},1

        local i = 1
        while true do
            local char = argStr:sub(i,i)
            i = i + 1

            if char:match("%s") then
                -- whitespace
                if args[curArg] then
                    curArg = curArg + 1
                end
            elseif char == "\"" then
                local buf = ""

                while true do
                    char = argStr:sub(i,i)
                    i = i + 1

                    if char == "\"" then
                        break
                    elseif char == "" then
                        error("Unfinished quote in command")
                    else
                        buf = buf..char
                    end
                end

                args[curArg] = buf
                curArg = curArg + 1
            elseif char == "" then
                break
            else
                args[curArg] = args[curArg] or ""
                args[curArg] = args[curArg]..char
            end
        end

        concommand.commands[cmd].callback(argStr,args)
    else
        error("Unknown command: "..cmd)
    end
end

concommand.Add("help","prints version and all registered commands",function()
    term:writeln("glua.team web console v"..WEBCONSOLE_VERSION)
    term:writeln("lovingly written in ".._VERSION)
    term:writeln("")

    term:writeln("commands: ")

    for cmd,data in pairs(concommand.commands) do
        term:write("    ")
        term:write(cmd)
        term:write("    ->    ")
        term:writeln(data.help)
    end
end)

concommand.Add("clock","starts a clock program that runs forever",function()
    while true do
        clearWholeLine()
        term:write(tostring(os.date("%c")))
        wait(100)
    end
end)

concommand.Add("members","lists all team members",function()
    shuffleTeam()

    term:write("glua.team roster as of ")
    term:writeln(os.date("%c"))
    term:writeln("(use `userinfo <name>` to get additional info")

    term:write("[ ")
    term:write("\x1b[1;3;33m")
    term:write("team lead")
    term:write("\x1b[0m")
    term:write("    ")
    term:write("\x1b[1;3;32m")
    term:write("team assistant")
    term:write("\x1b[0m")
    term:write("    ")
    term:write("\x1b[1;3;36m")
    term:write("ctf roster")
    term:write("\x1b[0m")
    term:write("    ")
    term:write("friend")
    term:writeln(" ]")

    for i,memberData in ipairs(members) do
        if memberData.role == "team lead" then
            term:write("\x1b[1;3;33m")
            term:write(memberData.name)
            term:write((" "):rep(longestName - utf8.len(memberData.name)))
            term:write("\x1b[0m")
        elseif memberData.role == "team assistant" then
            term:write("\x1b[1;3;32m")
            term:write(memberData.name)
            term:write((" "):rep(longestName - utf8.len(memberData.name)))
            term:write("\x1b[0m")
        elseif memberData.role == "ctf roster" then
            term:write("\x1b[1;3;36m")
            term:write(memberData.name)
            term:write((" "):rep(longestName - utf8.len(memberData.name)))
            term:write("\x1b[0m")
        else
            term:write(memberData.name)
            term:write((" "):rep(longestName - utf8.len(memberData.name)))
        end

        if i % 4 == 0 then
            term:writeln("")
        else
            term:write("    ")
        end
    end

    if #members % 6 ~= 0 then term:writeln("") end
end)

concommand.Add("userinfo","lists member info",function(argStr,args)
    local name = argStr:lower()
    assert(name,"argument 1 needs to be a username!")

    local memberData = membersByName[name]
    if not memberData then
        error("User `"..name.."` does not exist")
    end

    term:writeln(memberData.name)

    if memberData.data.steamID64 then
        term:write("Steam profile: https://steamcommunity.com/profiles/")
        term:writeln(memberData.data.steamID64)
    end

    if memberData.data.twitter then
        term:write("Twitter: https://twitter.com/")
        term:writeln(memberData.data.twitter)
    end

    if memberData.data.keybase then
        term:write("Keybase: https://keybase.io/")
        term:writeln(memberData.data.keybase)
    end

    if memberData.data.github then
       term:write("GitHub: https://github.com/")
       term:write(memberData.data.github)
       term:writeln("/")
    end
end)

local function _pack(...) return {len = select("#",...),...} end
local function _unpack(t) return table.unpack(t,1,t.len) end

concommand.Add("l","runs lua",function(argStr,args)
    local code = "return "..argStr
    local fn,err = load(code)

    if not fn then
        code = argStr
        fn,err = load(code)
    end

    if fn then
        local ret = _pack(fn(code))

        for i=1,ret.len do
            ret[i] = tostring(ret[i])
        end

        term:writeln(table.concat(ret,"    "))
    else
        error(err)
    end
end)

concommand.Add("links","prints all useful URLs",function()
    term:writeln("Discord Server: https://discord.gg/6rsbUU8")
    term:writeln("Steam Group: https://steamcommunity.com/groups/glua")
    term:writeln("Github: https://glua.github.io")
end)

concommand.Add("skidquiz","starts an interactive skid quiz",function()
    local function query(question,options)
        term:writeln(question)
        for i,opt in ipairs(options) do
            term:write("  ")
            term:write(tostring(i))
            term:write(". ")
            term:writeln(tostring(opt))
        end

        while true do
            term:write("Your answer: ")

            local ans = queryInput()

            ans = tonumber(ans)

            if not ans or ans ~= ans or not options[ans] then
                term:writeln("Invalid option, try again.")
            else
                return ans
            end
        end
    end

    local function queryBool(question)
        return query(question,{"Yes","No"}) == 1
    end

    local quizType = query("How would you like to do this quiz?",{"Electronically","Via post"})

    if quizType == 2 then
        term:writeln("Please fill this out and post it to us: https://glua.team/skidquiz.png")
        return
    end

    term:writeln("When you have completed this form, all data will be sent to the BIG SERVER MEN for processing.")
    term:writeln("Confirmed non-skids will receive their skid pass in 5 to 5e99 business days.")
    term:writeln("")
    term:writeln("Cheating will result in being placed on the B.S.M. blacklist and immediate forced ejection from the Garry's Mod community.")
    term:writeln("")
    term:writeln("You don't want to be the next serverwatch. Do you?")
    term:writeln("")
    term:writeln("")
        
    local response = {}

    response.postsOnOrVisitsCheatForums = queryBool("I regularly post on, or visit mpgh.net, hackforums.net, or gmodcheats.com")
    response.postsOnLeakForums = queryBool("I regularly post on leakforums.net")
    response.bannedFromMarketplace = queryBool("I have been banned from coderhire, scriptfodder or mod mountain")
    response.serverwatch = query("My relation to serverwatch: ",{
        "I don't know this person",
        "I am a friend",
        "I AM serverwatch",
    })
    response.playsPropkill = queryBool("I regularly play propkill")
    response.usesYoutube = queryBool("Youtube is my primary source for technical information")
    response.wantsToMakeHack = queryBool("My greatest ambition and primary motivation for learning glua is to make another shitty lua hack")
    response.facepunchShitposting = queryBool("I have posted on facepunch or in the glua group, asking how to code a cheat or anticheat")
    response.darkRPTroubles = query("I have posted on facepunch or in the glua group, asking for help with my DarkRP server",{
        "Yes",
        "Yes, oh god it was terrible! And it involved jobs.lua too! :'(",
        "No",
    })
    response.steamWorkshopShitposting = queryBool("I have had one or more items on the steam workshop deleted")
    response.shitAnticheatWriter = queryBool("I think an anticheat banning players for naughty filenames is acceptable")
    response.blackHatFanboi = queryBool("I admire, look up to, hero worship, or would like to join Anonymous, Lizard Squad, LulzSec, Poodlecorp, FaZe clan, Garry's Mod Lua Steam Chat, or some other shitty group of \"Black Hat\" manchildren")

    response.cacBypassInMail = queryBool("Please send me my one line CAC bypass in the mail")
    response.obfuscatorSkid = queryBool("I obfuscate all my code")
    response.cryptoIdiot = queryBool("BASE64 is a form of encryption")
    response.skidWebsiteMember = query("I appear on ___ cheater.team-like websites",{
        "0",
        "I AM on the cheater.team website",
        "1-5",
        "5-10",
        "10-1337",
    })

    response.idkButThisIsFunny = queryBool("HEY GUYS !CAKE IS MORALLY BANKRUPT!")

    term:writeln("")
    term:writeln("FINAL QUESTION!")

    response.theFuckGarryDid = query("the fuck garry did?",{
        [[A table containing the values {"dog","cat"}]],
        [[A coroutine.]],
        [[A table containing itself.]],
        [[Garry did the fuck!]],
        [[javascript]],
    })

    term:writeln("")

    response.name = queryRaw("Your name: ")
    response.steamID = queryRaw("Your SteamID: ")
    response.mpghAccount = queryRaw("Your MPGH Account: ")

    term:writeln("")

    --[[
        Parakeet👻 - Today at 3:14 PM
        woah
        for added touch, when complete, it should just try to print the page and then ask you to fax it to big server men(edited)
    ]]


    term:writeln("printing...")
    
    local printWindow = window:open()
    
    printWindow.document:open("text/plain")
    printWindow.document:write(js.global.JSON:Stringify(response))
    printWindow.document:close()
    printWindow:focus()
    printWindow:print()
    printWindow:close()
    
    term:writeln("Please fax this print-out to the Big Server Men conglomerate")
    term:writeln("Thank you for your time and interest")
end)

local function main(doStartup)
    if doStartup then
        for line in gluaLogo:gmatch("([^\r\n]*)\r?\n") do
            term:writeln(line)
        end

        term:writeln("")

        concommand.Run("members")

        term:writeln("")

        term:writeln("type `help` for all commands, or `links` to get in touch with us")

        term:write(prompt)
    end

    while true do
        local line = coroutine.yield()

        linehistory[#linehistory + 1] = linebuffer
        currentHistory = #linehistory + 1
        tempLine = false
        lrPos = 0
        linebuffer = ""

        MAINTHREAD_RUNNING = true
        xpcall(function()
            concommand.Run(line)
        end,function(err)
            term:write("\x1b[1;3;31m")
            term:write(err)
            term:writeln("\x1b[0m")
        end)
        term:write(prompt)

        MAINTHREAD_RUNNING = false
    end
end

local mainthread = coroutine.create(main)

term:attachCustomKeyEventHandler(function(_,ev)
    if ev.altKey then return false end
    if ev.altGraphKey then return false end
    if ev.ctrlKey then
        if ev.code ~= "KeyC" then return false end
    end
    if ev.metaKey then return false end

    if ev.code == "ArrowUp" then
        if not tempLine then
            tempLine = linebuffer
        end

        currentHistory = math.max(1,currentHistory - 1)

        if linehistory[currentHistory] then
            term:write((" "):rep(#linebuffer - lrPos))
            term:write(("\b \b"):rep(#linebuffer))
            linebuffer = linehistory[currentHistory]
            lrPos = #linebuffer
            term:write(linebuffer)
        end

        return true
    elseif ev.code == "ArrowDown" then
        currentHistory = math.min(#linehistory + 1,currentHistory + 1)
        if linehistory[currentHistory] then
            term:write(("\b \b"):rep(#linebuffer))
            linebuffer = linehistory[currentHistory]
            lrPos = #linebuffer
            term:write(linebuffer)
        elseif tempLine then
            term:write(("\b \b"):rep(#linebuffer))
            linebuffer = tempLine
            lrPos = #linebuffer
            tempLine = false
            term:write(linebuffer)
        end

        return true
    end
end)

term:on("key",function(_,key,ev)
    if ev.altKey then return end
    if ev.altGraphKey then return end
    if ev.ctrlKey then
        if ev.code == "KeyC" then
            murderedCoroutines[mainthread] = true
            mainthread = coroutine.create(main)
            coroutine.resume(mainthread,false)
            term:writeln("")
            term:write(prompt)
            tempLine = false
            lrPos = 0
            linebuffer = ""
            MAINTHREAD_RUNNING = false
        end

        return
    end
    if ev.metaKey then return end

    if not inputIsActive then return end
    if MAINTHREAD_RUNNING then return end

    if ev.code == "ArrowUp" then return end
    if ev.code == "ArrowDown" then return end

    if ev.code == "Backspace" then
        if lrPos > 0 then
            term:write((" "):rep(#linebuffer - lrPos))
            term:write(("\b \b"):rep(#linebuffer))
            linebuffer = linebuffer:sub(1,lrPos - 1)..linebuffer:sub(lrPos + 1,-1)
            term:write(linebuffer)
            term:write(("\x1b[D"):rep(math.max(0,#linebuffer - lrPos + 1)))
            lrPos = lrPos - 1
            return
        end
    elseif ev.code == "Delete" then
        if lrPos >= 0 then
            term:write((" "):rep(#linebuffer - lrPos))
            term:write(("\b \b"):rep(#linebuffer))
            linebuffer = linebuffer:sub(1,lrPos)..linebuffer:sub(lrPos + 2,-1)
            term:write(linebuffer)
            term:write(("\x1b[D"):rep(math.max(0,#linebuffer - lrPos)))
            return
        end
    elseif (ev.code == "Enter") or (key == "\n") or (key == "\r") or (key == "\r\n") then
        term:write("\r\n")
        coroutine.resume(mainthread,linebuffer)
    elseif ev.code == "ArrowLeft" then
        if lrPos > 0 then
            lrPos = lrPos - 1
            term:write(key)
        end
    elseif ev.code == "ArrowRight" then
        if lrPos < #linebuffer then
            lrPos = lrPos + 1
            term:write(key)
        end
    elseif key then
        term:write((" "):rep(#linebuffer - lrPos))
        term:write(("\b \b"):rep(#linebuffer))
        linebuffer = linebuffer:sub(1,lrPos)..key..linebuffer:sub(lrPos + 1,-1)
        lrPos = lrPos + 1
        term:write(linebuffer)
        term:write(("\x1b[D"):rep(math.max(0,#linebuffer - lrPos)))
    end
end)

term:blur()
js.global:setTimeout(function()
    term:clear()
    term:focus()

    coroutine.resume(mainthread,true)
end,100)

local function restart()
    term:blur()

    wait(100)
    term:clear()
    term:focus()

    mainthread = coroutine.create(main)
    coroutine.resume(mainthread,true)
    tempLine = false
    lrPos = 0
    linebuffer = ""
    MAINTHREAD_RUNNING = false
    coroutine.yield()
end

concommand.Add("restart","soft-restarts the terminal emulator",restart)
concommand.Add("clear","clears the terminal emulator",function()
    term:blur()

    wait(100)
    term:clear()
    term:focus()
end)
