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

type `help` for all commands
]]

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

local function clearWholeLine()
    term:write(("\b \b"):rep(255))
end

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

local function main(doStartup)
    if doStartup then
        for line in gluaLogo:gmatch("([^\r\n]*)\r?\n") do
            term:writeln(line)
        end

        term:write(prompt)
    end

    while true do
        local line = coroutine.yield()

        MAINTHREAD_RUNNING = true
        xpcall(function()
            concommand.Run(line)
        end,function(err)
            term:write("\x1b[1;3;31m")
            term:write(err)
            term:writeln("\x1b[0m")
        end)
        term:write(prompt)
        linehistory[#linehistory + 1] = linebuffer
        currentHistory = #linehistory + 1
        tempLine = false
        lrPos = 0
        linebuffer = ""
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
    elseif ev.code == "Enter" then
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
        term:write(key)
        linebuffer = linebuffer:sub(1,lrPos)..key..linebuffer:sub(lrPos + 1,-1)
        lrPos = lrPos + 1
    end
end)

term:blur()
js.global:setTimeout(function()
    term:clear()
    term:focus()

    coroutine.resume(mainthread,true)
end,100)
