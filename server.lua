--- Server program that actually plays audio.



local ok, err = pcall(parallel.waitForAny,)

if not ok then
  printError(err)
end
