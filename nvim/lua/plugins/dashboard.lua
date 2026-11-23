return {
  {
    "snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = vim.tbl_deep_extend("force", opts.dashboard or {}, {
        preset = {
          header = [[
       ..:.               ..
      :'  ':..       ..:''':.
     :'   ..::::::::''  .::::
    ::    ::'.::'     .:::: :.
   ::' .  '   '   .   '' :: ::
  .: .:::       ::::.     '.:
 .:  :::' .     :::::      ::
 :     .:'.:''' ''''      '::
':   .:'.''               .:::
 :   :: :.......        :::::'
':::'''     :.:'::.. ...:::::
  :  .  .  :''''::::::::::::
 :'... ..: :      '::::::'''
:: ::    :.::.      ':::::
 :.::....::::::.::::::::::.   ]],
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      })
    end,
  },
}
