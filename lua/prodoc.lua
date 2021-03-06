local vim,api = vim,vim.api
local prodoc = {}
local space = ' '
local _split = require('prodoc.utils')._split

local prefix = function()
  local ft = vim.bo.filetype
  local has_lang,lang = pcall(require,'prodoc.'..ft)
  if not has_lang then
    error('Current filetype %s does not support')
    return
  end
  return lang.prefix
end

local prefix_with_doc = function(pf,params)
  local prefix_doc = {}
  local doc_summary = '@Summary '
  local doc_description = '@Description '
  local doc_param = '@Param '

  table.insert(prefix_doc,pf .. space .. doc_summary)
  table.insert(prefix_doc,pf .. space .. doc_description)
  for _,v in ipairs(params) do
    local p = pf .. space .. doc_param .. space .. v
    table.insert(prefix_doc,p)
  end

  return prefix_doc
end

local generate_line_comment = function(co)
  while true do
    local _,line,lnum,comment_prefix = coroutine.resume(co)
    if coroutine.status(co) == 'dead' then
      break
    end
    if _split(line,'%S+')[1] == comment_prefix then
      local pre_line = line:gsub(comment_prefix..space,'',1)
      api.nvim_buf_set_lines(0,lnum-1,lnum,true,{pre_line})
    else
      api.nvim_buf_set_lines(0,lnum-1,lnum,true,{comment_prefix ..space..line})
    end
  end
end

function prodoc.generate_comment(...)
  local lnum1,lnum2 = ...

  if not vim.bo.modifiable then
    error('Buffer is not modifiable')
    return
  end

  local comment_prefix = prefix()

  local normal_mode = coroutine.create(function()
    local lnum = api.nvim_win_get_cursor(0)[1]
    local line = vim.fn.getline('.')
    coroutine.yield(line,lnum,comment_prefix)
  end)

  local visual_mode = coroutine.create(function()
    local vstart = vim.fn.getpos("'<")
    local vend = vim.fn.getpos("'>")
    local line_start,_ = vstart[2],vstart[3]
    local line_end,_ = vend[2],vend[3]
    local lines = vim.fn.getline(line_start,line_end)

    for k,line in ipairs(lines) do
      coroutine.yield(line,line_start+k-1,comment_prefix)
    end
  end)

  if lnum1 == lnum2 then
    generate_line_comment(normal_mode)
    return
  end

  generate_line_comment(visual_mode)
end

-- generate doc
function prodoc.generate_doc()
  local ft = vim.bo.filetype
  local comment_prefix = prefix()
  local lnum = api.nvim_win_get_cursor(0)[1]
  local line = vim.fn.getline('.')
  local params = require('prodoc.'..ft).get_params(lnum,line,_split)

  local doc = prefix_with_doc(comment_prefix,params)

  -- insert doc
  vim.fn.append(lnum-1,doc)
  -- set curosr
  vim.fn.cursor(lnum,#doc[1]+#comment_prefix+1)
  -- enter into insert mode
  api.nvim_command('startinsert!')
end

function prodoc.generate_command()
  api.nvim_command('command! -range -bar ProDoc lua require("prodoc").generate_doc()')
  api.nvim_command('command! -range -bar ProComment lua require("prodoc").generate_comment(<line1>,<line2>)')
end

return prodoc
