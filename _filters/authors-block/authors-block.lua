--[[
authors-block – affiliations block extension for quarto

Copyright (c) 2023 Lorenz A. Kapsner

Permission to use, copy, modify, and/or distribute this software for any purpose
with or without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
THIS SOFTWARE.
]]

local List = require 'pandoc.List'
local utils = require 'pandoc.utils'
local stringify = utils.stringify

-- [import]
local from_utils = require "utils"
local normalize_affiliations = from_utils.normalize_affiliations
local normalize_authors = from_utils.normalize_authors
local normalize_latex_authors = from_utils.normalize_latex_authors

local from_authors = require "from_author_info_blocks"
local default_marks = from_authors.default_marks
local create_equal_contributors_block = from_authors.create_equal_contributors_block
local create_affiliations_blocks = from_authors.create_affiliations_blocks
local create_correspondence_blocks = from_authors.create_correspondence_blocks
local is_corresponding_author = from_authors.is_corresponding_author
local author_inline_generator = from_authors.author_inline_generator
local create_authors_inlines = from_authors.create_authors_inlines
-- [/import]

-- This is the main-part

local function meta_string(value)
  if not value then
    return nil
  end
  if type(value) == "table" and value.t == "MetaBool" then
    return value.c and "true" or "false"
  end
  local str = stringify(value)
  if str == "" then
    return nil
  end
  return str
end

local function meta_to_blocks(value)
  if not value then
    return {}
  end
  if type(value) == "table" then
    if value.t == "MetaBlocks" then
      return value.c or {}
    elseif value.t == "MetaInlines" then
      return { pandoc.Para(value.c or {}) }
    elseif value.t == "MetaString" then
      return { pandoc.Para({ pandoc.Str(value.c) }) }
    end
  end
  local str = meta_string(value)
  if str then
    return { pandoc.Para({ pandoc.Str(str) }) }
  end
  return {}
end

local function styled_para(inlines, style)
  inlines = inlines or {}
  local attributes = { ["custom-style"] = style }

  if FORMAT:match 'latex' then
    if style == "Abstract Title" or style == "Abstract" then
      local latex_inlines = {}
      if style == "Abstract Title" then
        table.insert(latex_inlines, pandoc.RawInline('latex', '\\small\\bfseries '))
      else
        table.insert(latex_inlines, pandoc.RawInline('latex', '\\small '))
      end
      for _, inline in ipairs(inlines) do
        table.insert(latex_inlines, inline)
      end

      return pandoc.Div(
        {
          pandoc.RawBlock('latex', '\\begin{center}'),
          pandoc.Para(latex_inlines),
          pandoc.RawBlock('latex', '\\end{center}')
        },
        pandoc.Attr("", {}, attributes)
      )
    elseif style == "Author" then
      local latex_inlines = { pandoc.RawInline('latex', '{\\small ') }
      for _, inline in ipairs(inlines) do
        table.insert(latex_inlines, inline)
      end
      table.insert(latex_inlines, pandoc.RawInline('latex', '}'))

      return pandoc.Div(
        { pandoc.Para(latex_inlines) },
        pandoc.Attr("", {}, attributes)
      )
    end

    return pandoc.Div(
      { pandoc.Para(inlines) },
      pandoc.Attr("", {}, attributes)
    )
  end

  return pandoc.Div(
    { pandoc.Para(inlines) },
    pandoc.Attr("", {}, attributes)
  )
end

local function restyle_blocks(blocks, style)
  local styled = List:new{}
  for _, block in ipairs(blocks or {}) do
    if block.t == "Para" or block.t == "Plain" then
      styled:insert(styled_para(block.c or {}, style))
    else
      styled:insert(block)
    end
  end
  return styled
end

local function make_abstract_blocks(abstract_meta, title_meta)
  local blocks = {}
  local content_blocks = meta_to_blocks(abstract_meta)
  if #content_blocks == 0 then
    return blocks
  end

  local title_text = meta_string(title_meta) or "Abstract"
  table.insert(blocks, styled_para({ pandoc.Str(title_text) }, "Abstract Title"))

  for _, block in ipairs(content_blocks) do
    if block.t == "Para" or block.t == "Plain" then
      table.insert(blocks, styled_para(block.c or {}, "Abstract"))
    else
      table.insert(blocks, block)
    end
  end

  return blocks
end

function Pandoc(doc)
  local meta = doc.meta
  local body = List:new{}
  local abstract_blocks = make_abstract_blocks(meta.abstract, meta["abstract-title"] or meta.abstract_title)
  local date_blocks = restyle_blocks(meta_to_blocks(meta.date), "Date")
  
  local mark = function (mark_name) return default_marks[mark_name] end

  body:extend(restyle_blocks(create_equal_contributors_block(meta.authors, mark), "Author"))
  body:extend(restyle_blocks(create_affiliations_blocks(meta.affiliations), "Author"))
  body:extend(restyle_blocks(create_correspondence_blocks(meta.authors, mark), "Author"))
  body:extend(date_blocks)
  body:extend(abstract_blocks)
  body:extend(doc.blocks)
  
  for _i, author in ipairs(meta.authors) do
    author.test = is_corresponding_author(author)
  end
  
  meta.affiliations = normalize_affiliations(meta.affiliations)
  meta.author = meta.authors:map(normalize_authors(meta.affiliations))
  
  -- Overwrite authors with formatted values. We use a single, formatted
  -- string for most formats. LaTeX output, however, looks nicer if we
  -- provide a authors as a list.
  meta.author = pandoc.MetaInlines(create_authors_inlines(meta.author, mark))
  -- Institute info is now baked into the affiliations block.
  meta.affiliations = nil
  meta.abstract = nil
  meta["abstract-title"] = nil
  meta.abstract_title = nil
  meta.date = nil

  return pandoc.Pandoc(body, meta)
end