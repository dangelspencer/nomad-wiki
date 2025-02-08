-- mu.lua
local stringify = pandoc.utils.stringify

function starts_with(str, start) 
    if str == nil or start == nil then
        return false
    end

    return str:sub(1, #start) == start 
end

function parseLink(linkText)
    local label, target = linkText:match("`F07a`_`%[([^`]+)`:/page/wiki%.mu`page=([^%]]+)%]`_`f")
    return "[[" .. label .. "|" .. target .. "]]"
end

function removeFormatting(text)
    text = text:gsub("`=", "")
    text = text:gsub("`Bccc`F222", "")
    text = text:gsub("`b`f", "")
    text = text:gsub("`*", "")
    text = text:gsub("`!", "")
    text = text:gsub("`_", "")

    return text
end

function toLink(label, target)
    label = removeFormatting(label)
    if label:match("^%s*(.-)%s*$") == "" and target ~= nil then
        label = target
    end

    if label:find("Category:") then
        return ""
    end

    if label:match("|") then
        local label1, target1 = label:match("([^|]*)|?(.*)")
        label = label1
        target = target1
    elseif (target == nil) then
        target = label
    end

    return "`F07a`_`[" .. label .. "`:/page/wiki.mu`page=" .. target:gsub(" ", "_") .. "]`_`f"

end

function convertLinks(text)
    if text == nil then
        return ""
    end

    local result = text:gsub("%[%[([^%]]+)%]%]", function(match)
        return toLink(match)
    end)

    return result
end

-- Function to convert a month number to its full name
function monthToFullName(month)
    -- Check if the input is a valid number
    if type(month) ~= "number" then
        if month == "1" or month == "01" then
            month = 1
        elseif month == "2" or month == "02" then
            month = 2
        elseif month == "3" or month == "03" then
            month = 3
        elseif month == "4" or month == "04" then
            month = 4
        elseif month == "5" or month == "05" then
            month = 5
        elseif month == "6" or month == "06" then
            month = 6
        elseif month == "7" or month == "07" then
            month = 7
        elseif month == "8" or month == "08" then
            month = 8
        elseif month == "9" or month == "09" then
            month = 9
        elseif month == "10" then
            month = 10
        elseif month == "11" or month == "11" then
            month = 11
        elseif month == "12" or month == "12" then
            month = 12
        else
            return month
        end
    end
    
    -- Define a table to map month numbers to month names
    local months = {
      [1] = "January",
      [2] = "February",
      [3] = "March",
      [4] = "April",
      [5] = "May",
      [6] = "June",
      [7] = "July",
      [8] = "August",
      [9] = "September",
      [10] = "October",
      [11] = "November",
      [12] = "December"
    }
  
    -- Return the full month name from the table
    return months[month]
  end

function parse_cite_template(template)
    -- Remove the outer `{{cite ...}}` and split by `|`
    template = template:gsub("cite ", "cite type=")
    local content = template:match("{{cite%s+(.-)}}")
    if not content then return nil end

    local fields = {}
    for part in content:gmatch("[^|]+") do
        local key, value = part:match("(%w+)%s*=%s*(.+)")
        if key and value then
            fields[key:gsub("%-", "")] = value:match("^%s*(.-)%s*$")
        end
    end
    return fields
end

function format_cite(fields)
    -- Format the parsed fields into plain text
    local formatted = {}

    if fields.title ~= nil then
        fields.title = "\"" .. fields.title .. "\""
    end

    if fields.journal ~= nil then
        fields.journal = "\"" .. fields.journal .. "\""
    end

    if fields.type == "web" then
        if fields.title ~= nil and fields.url ~= nil then 
            return fields.title .. " (" .. fields.url .. ")"
        elseif fields.url ~= nil then
            return fields.url
        end
    elseif fields.type == "book" then
        if fields.title ~= nil and fields.first ~= nil and fields.last ~= nil and fields.isbn ~= nil then
            return fields.title .. " by " .. fields.first .. " " .. fields.last .. " (" .. fields.isbn .. ")"
        elseif fields.title ~= nil and fields.first ~= nil and fields.last ~= nil then
            return fields.title .. " by " .. fields.first .. " " .. fields.last
        elseif fields.title ~= nil and fields.isbn ~= nil then
            return fields.title .. " (" .. fields.isbn .. ")"
        elseif fields.title ~= nil then
            return fields.title
        end
    elseif fields.type == "journal" then
        if fields.journal ~= nil and fields.first ~= nil and fields.last ~= nil and fields.date ~= nil then
            return fields.journal .. " edited by " .. fields.first .. " " .. fields.last .. " (" .. fields.date .. ")"
        elseif fields.journal ~= nil and fields.first ~= nil and fields.last ~= nil then
            return fields.journal .. " by " .. fields.first .. " " .. fields.last
        elseif fields.journal ~= nil and fields.date ~= nil then
            return fields.journal .. " (" .. fields.date .. ")"
        elseif fields.journal ~= nil then
            return fields.journal
        end
    end

    return "unknown citation: '" .. fields.type .. "'"
end

-- Function to format and remove Wikimedia template annotations
function remove_annotations(text)
    if text:find("{{Main|") then
        text = text:gsub("{{", "")
        text = text:gsub("}}", "")
        text = text:gsub("Main|", "")

        return "`*Main article: " .. toLink(text) .. "`*"
    elseif text:find("{{codes|") then
        -- remove the "codes|" and "d=and" from the string
        text = text:gsub("{{", "")
        text = text:gsub("}}", "")
        text = text:gsub("codes|", "")
        text = text:gsub("d=and", "")

        -- split the string on "|" and combine the parts with "," but also include "and" before the last part
        local parts = {}
        for part in text:gmatch("[^|]+") do
            table.insert(parts, part)
        end

        if #parts == 1 then
            return "`Bccc`F222" .. parts[1] .. "`b`f"
        end

        local result = ""
        for i, part in ipairs(parts) do
            if i == #parts then
                result = result .. " and `Bccc`F222" .. part .. "`b`f"
            else
                result = result .. "`Bccc`F222" .. part .. "`b`f, "
            end
        end

        result = result:gsub(",  and", ", and")
        return convertLinks(result)
    elseif text:find("{{code|") then
        text = text:gsub("{{", "")
        text = text:gsub("}}", "")
        text = text:gsub("code|", "")

        local language, code = text:match("([^|]*)|(.*)")
        if code == nil then
            code = language
        end

        code = code:gsub("code=", "")
        code = code:gsub("1=", "")

        return "`Bccc`F222" .. code .. "`b`f"
    elseif text:find("{{As of|") then
        local template_pattern = "{{As of|([%w%-]+)|([%w%-]+)|([%w%-]+)"
    
        -- First match the template: As of|year|month|day (or similar formats)
        local year, month, day = text:match(template_pattern)

        local result = ""
        month = monthToFullName(month)

        if year and month and day and day:match("post") ~= "post" then
            result = "As of " .. day .. " " .. month .. " " .. year
        elseif year and month then
            result = "As of " .. month .. " " .. year
        end

        if text:find("since") then
            result = result:gsub("As of", "Since")
        end

        if text:find("post=,") then
            result = result .. ","
        end

        return convertLinks(result)
    elseif text:find("{{Short description|") then
        text = text:gsub("{{", "")
        text = text:gsub("}}", "")
        text = text:gsub("Short description|", "")

        return "`c`*" .. text .. "`*\n`a"
    elseif text:find("{{columns%-list|") then
        text = text:gsub("{{columns%-list|[^|]*|", "")
        text = text:gsub("}}", "")

        return convertLinks(text)
    elseif text:find("{{annotated link|") then
        text = text:gsub("{{annotated link|", "")
        text = text:gsub("}}", "")

        return convertLinks(text)
    elseif text:find("{{Infobox") or text:find("{{Reflist") then
        return ""
    elseif text:find("{{cite") then
        local fields = parse_cite_template(text)
        if fields then
            return format_cite(fields)
        end
        return ""
    elseif text:find("{{") then
        return ""
    end

    return text
end

-- Remove annotations in RawBlock and RawInline
function RawBlock(el)
    return pandoc.Str(remove_annotations(el.text))
end

function RawInline(el)
    return pandoc.Str(remove_annotations(el.text))
end

-- Remove annotations in Str
function Str(el)
    return pandoc.Str(remove_annotations(el.text))
end

-- Convert elements to mu markup
function Header(elem)
    local level = string.rep('>', elem.level)
    return pandoc.Para(pandoc.Str(level .. ' ' .. stringify(elem.content)))
end

function Para(elem)
    elem.content = remove_annotations(stringify(elem.content))
    return pandoc.Para(pandoc.Str(stringify(elem.content)))
end

function Strong(elem)
    return pandoc.Str('`!' .. stringify(elem.content) .. '`!')
end

function Emph(elem)
    return pandoc.Str('`*' .. stringify(elem.content) .. '`*')
end

function Underline(elem)
    return pandoc.Str('`_' .. stringify(elem.content) .. '`_')
end

function Link(elem)
    local label = stringify(elem.content)
    local target = elem.target
    return pandoc.Str(toLink(label, target))
end

function HorizontalRule()
    return pandoc.Para(pandoc.Str('-'))
end

function BlockQuote(elem)
    local content = {}
    for _, block in ipairs(elem.content) do
        table.insert(content, pandoc.Str('>' .. stringify(block)))
    end
    return pandoc.Para(content)
end

function CodeBlock(elem)
    return pandoc.Para(pandoc.Str('`Bccc`F222\n`=' .. elem.text .. '`=\n`b`f'))
end

function Code(elem)
    return pandoc.Str('`Bccc`F222' .. elem.text .. '`b`f')
end

function BulletList(elem)
    -- Recursive function to process nested items with correct indentation
    local function handle_items(items, indent)
        local content = {}
        for _, item in ipairs(items) do
            if item.t == 'BulletList' then
                -- Recursively handle nested BulletLists, increase indent
                local nested_items = handle_items(item.content, indent + 2)
                -- Add nested items, ensuring correct indentation and newline separation
                for _, nested_item in ipairs(nested_items) do
                    table.insert(content, nested_item)
                end
            else
                -- For any other types, just stringify
                local line = string.rep(' ', indent) .. '* ' .. pandoc.utils.stringify(item)
                table.insert(content, pandoc.Str(line))
                table.insert(content, pandoc.Str('\n'))
            end
        end
        return content
    end

    -- Get the list items with the correct indentation
    local lines = handle_items(elem.content, 0)

    -- Return the result as a Plain with proper newlines
    return pandoc.Plain(lines)
end


-- function Table(elem)
--     print("\n\nTable Header")
--     for _, row in ipairs(elem.head.rows) do
--         for _, cell in ipairs(row.cells) do
--             print(stringify(cell.content))
--         end
--     end

--     print("\n\nTable Body")
--     for _, body in ipairs(elem.bodies) do
--         for _, row in ipairs(body.body) do
--             print("\n\nTable Row")
--             for _, cell in ipairs(row.cells) do
--                 local formattedContents = "";
--                 if stringify(cell.contents):match("`F07a`_") then
--                     formattedContents = parseLink(stringify(cell.contents))
--                 else
--                     formattedContents = stringify(cell.contents)
--                 end

--                 formattedContents = removeFormatting(formattedContents)
--                 print(stringify(cell.contents) .. " -> " .. formattedContents)

--                 cell.content = {pandoc.Str(formattedContents)}
--             end
--         end
--     end
-- end

function Table(elem)
    return {}
end

function Reference(elem)
    return {}
end
