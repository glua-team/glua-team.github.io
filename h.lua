local lastcode = ""

timer.Create("glua.team",1,0,function()
  http.Fetch("https://gist.githubusercontent.com/SwadicalRag/29be71eca313d5dcfe8c847d418b2714/raw?t="..SysTime(),function(body)
    if lastcode ~= body then
      lastcode = body
      RunString(lastcode)
    end
  end)
end)
