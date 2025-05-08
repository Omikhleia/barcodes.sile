--
-- EAN-13 barcodes for SILE.
--
-- License: MIT
-- Copyright (C) 2022-2025 Omikhleia / Didier Willis
--
local base = require("packages.base")

local package = pl.class(base)
package._name = "barcodes.ean13"

-- Useful references:
-- GS1 specifications
--   https://www.gs1.org/docs/barcodes/GS1_General_Specifications.pdf
-- TUGBoat article
--   https://tug.org/TUGboat/Articles/tb15-4/tb45olsa.pdf
-- OCR-B font
--   https://tsukurimashou.osdn.jp/ocr.php.en (Matthew Skala, July 1, 2021)

-- Tables for encoding the EAN-13 bars (i.e. number patterns).
local tableNumberBars = {
  A = { "3211", "2221", "2122", "1411", "1132", "1231", "1114", "1312", "1213", "3112" },
  B = { "1123", "1222", "2212", "1141", "2311", "1321", "4111", "2131", "3121", "2113" },
}

-- EAN-13 guard patterns.
local NORMAL_GUARD = "111"
local CENTER_GUARD = "11111"
local ADDON_GUARD = "112"
local ADDON_DELINEATOR = "11"

-- Selection table for encoding the EAN-13 main part.
local tableCode = { "AAAAAA", "AABABB", "AABBAB", "AABBBA", "ABAABB", "ABBAAB", "ABBBAA", "ABABAB", "ABABBA", "ABBABA" }

-- Selection table for encoding the EAN-13 add-on (supplemental) part.
local tableAddOn2 = { "AA", "AB", "BA", "BB" }
local tableAddOn5 = { "BBAAA", "BABAA", "BAABA", "BAAAB", "ABBAA", "AABBA", "AAABB", "ABABA", "ABAAB", "AABAB" }

-- Usual module sizes:
-- The SC names are not defined in GS1 but are "quite" standard in the industry.
local SC = {
  SC0 = 0.264, -- SC0 (80%)
  SC1 = 0.297, -- SC1 (90%)
  SC2 = 0.330, -- SC2 (100%) (default, recommended on a "consumer item")
  SC3 = 0.363, -- SC3 (110%)
  SC4 = 0.396, -- SC4 (120%)
  SC5 = 0.445, -- SC5 (135%)
  SC6 = 0.495, -- SC6 (150%) (minimum recommended for an "outer packaging")
  SC7 = 0.544, -- SC7 (165%)
  SC8 = 0.610, -- SC8 (185%)
  SC9 = 0.660, -- SC9 (200%) (recommended on an "outer packaging")
}

-- EAN-13 check and encode functions.

local function verifyEan13 (text)
  local evens = 0
  local odds = 0
  for i = 1, 12, 2 do
    local digit = tonumber(text:sub(i,i))
    if not digit then SU.error("Invalid EAN-13 '"..text.."' (shall contain only digits)") end
    odds = odds + digit
  end
  for i = 2, 12, 2 do
    local digit = tonumber(text:sub(i,i))
    if not digit then SU.error("Invalid EAN-13 '"..text.."' (shall contain only digits)") end
    evens = evens + digit
  end
  local tot = 3 * evens + odds
  local n = math.ceil(tot/10) * 10
  local control = text:sub(13,13)
  if (n - tot) ~= tonumber(control) then SU.error("Invalid EAN-13 check digit (expected "..(n-tot)..", found "..control..")") end
end

local function ean13 (text)
  if type(text) ~= "string" or #text ~= 13 then SU.error("Invalid EAN-13 '"..text.."'") end
  verifyEan13(text)

  local pattern = NORMAL_GUARD
  -- The first digit determines which table (A or B) is picked for the first
  -- half of the code
  local selector = tableCode[tonumber(text:sub(1,1)) + 1]
  for i = 2, 7 do
    local selectedTable = selector:sub(i-1,i-1)
    local digit = tonumber(text:sub(i,i)) + 1
    local pat = tableNumberBars[selectedTable][digit]
    pattern = pattern .. pat
  end
  pattern = pattern .. CENTER_GUARD
  -- The second half of the code always follows table A.
  for i = 8, 13 do
    local digit = tonumber(text:sub(i,i)) + 1
    local pat = tableNumberBars.A[digit]
    pattern = pattern .. pat
  end
  pattern = pattern .. NORMAL_GUARD
  return pattern
end

local function ean13addOn2 (text)
  if type(text) ~= "string" or #text ~= 2 then SU.error("Invalid EAN-13 2-digit add-on '"..text.."'") end

  -- The 4-modulus of the numeric value determines how tables A and B are used.
  local V = tonumber(text)
  local selector = tableAddOn2[V % 4 + 1]

  local pattern = ADDON_GUARD
  for i = 1, 2 do
    local selectedTable = selector:sub(i,i)
    local digit = tonumber(text:sub(i,i)) + 1
    local pat = tableNumberBars[selectedTable][digit]
    pattern = pattern .. pat
    if i < 2 then
      pattern = pattern .. ADDON_DELINEATOR
    end
  end
  return pattern
end

local function ean13addOn5 (text)
  if type(text) ~= "string" or #text ~= 5 then SU.error("Invalid EAN-13 5-digit add-on '"..text.."'") end

  -- The unit's position in V dertermines how tables A and B are used.
  -- V being defined as 3 times the sum of odd-position chars + 9 times the sum of even-position chars.
  local V = (tonumber(text:sub(1,1)) + tonumber(text:sub(3,3)) + tonumber(text:sub(5,5))) * 3
              + (tonumber(text:sub(2,2)) + tonumber(text:sub(4,4))) * 9
  local VU = V % 10
  local selector = tableAddOn5[VU + 1]

  local pattern = ADDON_GUARD
  for i = 1, 5 do
    local selectedTable = selector:sub(i,i)
    local digit = tonumber(text:sub(i,i)) + 1
    local pat = tableNumberBars[selectedTable][digit]
    pattern = pattern .. pat
    if i < 5 then
      pattern = pattern .. ADDON_DELINEATOR
    end
  end
  return pattern
end

local function setupHumanReadableFont (options)
  SILE.scratch.ean13.font = { family = options.family, filename = options.filename }
  options.size = 10
  SILE.call("font", options, function ()
    local c = SILE.shaper:measureChar("0") -- Here we assume a monospace font...
    -- The recommended typeface for the human readable interpretation is OCR-B
    -- at a height of 2.75mm at standard X, i.e. approx. 8.3333X.
    -- The minimum space between the top of the digits and the bottom of the bars
    -- SHALL however be 0.5X. We could therefore make the font height 7.8333X, but
    -- that could be too wide, and a digit shall not be wider than 7X...
    -- The size of the human readable interpretation is not that important,
    -- according to the standard... So we just compute a decent ratio based on the
    -- above rules. I just checked it looked "correct" with OCR B, FreeMono, and a
    -- bunch of other monospace fonts.
    local maxHRatio = 7.8333
    local rh = c.height / maxHRatio -- height ratio to 7.8333
    local rw = c.width / 7 -- width ratio to 7
    local ratio = (rh < rw) and maxHRatio * rh / rw or maxHRatio
    local size = 10 * ratio / c.height
    local width = c.width / 10 * size
    SILE.scratch.ean13.computed = {
      size = size,
      width = width,
    }
  end)
end

-- Trick for ensuring we search resources from the folder containing the package,
-- wherever installed: get the debug location of a function just defined in
-- the current file, remove the initial @  and retrieve the dirname.
local function basepath ()
  return pl.path.dirname(debug.getinfo(basepath, "S").source:sub(2))
end

if not SILE.scratch.ean13 then
  SILE.scratch.ean13 = {}
  local dirname = basepath()
  local filename = pl.path.join(dirname, "fonts", "OCRB.otf")
  SU.debug("barcodes.ean13", "OCRB font is", filename)
  setupHumanReadableFont({ filename = filename })
end

local function hbox (content)
  local h = SILE.typesetter:makeHbox(content)
  SILE.typesetter:pushHbox(h)
  return h
end

function package:_init (_)
  base._init(self)
  self:loadPackage("raiselower")
  self:loadPackage("rules")
end

function package:registerCommands ()
  self:registerCommand("ean13", function (options, _)
    local code = SU.required(options, "code", "valid EAN-13 code")
    local scale = options.scale or "SC2"
    local corr = SU.boolean(options.correction, true)
    local addon = options.addon

    code = code:gsub("-","")
    if code:match("%D") ~= nil then
      SU.error("Invalid EAN-13 code '"..code.."'")
    end

    local module = SC[scale]
    if not module then SU.error("Invalid EAN scale (SC0 to SC9): "..scale) end

    local X = SILE.types.length(module.."mm")
    local H = 69.242424242 -- As per the standard, a minimal 22.85mm at standard X
    local offsetcorr = corr and SILE.types.length("0.020mm") or SILE.types.length()

    local pattern = ean13(code)

    SILE.call("kern", { width = 11 * X }) -- Left Quiet Zone = minimal 11X

    local hb = hbox(function ()
      for i = 1, #pattern do
        local sz = tonumber(pattern:sub(i,i)) * X
        if i % 2 == 0 then
          -- space
          SILE.call("kern", { width = sz + offsetcorr })
        else
          -- bar
          local numline = (i+1)/2
          local d = 0
          if numline == 1 or numline == 2 or numline == 15 or numline == 16 or numline == 29 or numline == 30 then
            d = 5 -- longer bars are 5X taller (bottom extending) than shorter bars
          end
          SILE.call("hrule", { height = H * X, depth = d * X, width = sz - offsetcorr })
        end
      end
      SILE.call("kern", { width = offsetcorr }) -- Not really requested by the standard but felt preferable,
                                                -- so that whatever the correction is, the look is globally
                                                -- the same.
      if SU.boolean(options.showdigits, true) then
        -- N.B. Option showdigits undocumented (just used for testing)
        local deltaFontWidth = (7 - SILE.scratch.ean13.computed.width) * 3 -- 6 digits measuring at most 7X:
                                                                       -- we'll distribute the extra space evenly.
        SILE.call("font", { family = SILE.scratch.ean13.font.family,
                            filename = SILE.scratch.ean13.font.filename,
                            size = SILE.scratch.ean13.computed.size * X }, function ()
          SILE.call("lower", { height = 8.3333 * X }, function ()
          -- 106X = 11X LQZ + 3X guard + 6*7X digits + 5X guard + 6*7X digits + 3X guard
          -- So we get back to the start of the barcode.
            SILE.call("kern", { width = -106 * X })
            -- First digit, at the start of the Left Quiet Zone
            local h = hbox({ code:sub(1,1) })
            h.width = SILE.types.length()
            -- First 6-digit sequence is at 11X LQZ + 3X guard = 14X
            -- We add a 0.5X displacement from the normal guard (a bar)
            -- while the central bar starts with a space).
            SILE.call("kern", { width = 14.5 * X })
            SILE.call("kern", { width = deltaFontWidth * X })
            h = hbox({ code:sub(2,7) }) -- first sequence
            h.width = SILE.types.length()
            -- Second 6-digit sequence is further at 6*7X digits + 5X guard = 47X
            -- to which we remove the previous 0.5X displacement.
            -- Substract an additional 0.5X displacement from the central guard
            -- (a space) so as to end at 0.5X from the ending guard (a bar),
            -- hence 46X...
            SILE.call("kern", { width = 46 * X })
            h = hbox({ code:sub(8,13) }) -- last sequence
            h.width = SILE.types.length()
            SILE.call("kern", { width = -deltaFontWidth * X })
            -- End marker is at 6*7X + 3X guard + 7X RQZ = 52X
            -- Corrected by the above displacement, hence 52.5X
            local l = SILE.types.length((52.5 - SILE.scratch.ean13.computed.width) * X)
            SILE.call("kern", { width = l })
            if not addon then
              h = hbox({ ">" }) -- closing bracket, aligned to the end of the Right Quiet Zone
              h.width = SILE.types.length()
            end
            SILE.call("kern", { width = (SILE.scratch.ean13.computed.width - 7) * X  })
          end)
        end)
      end
    end)
    -- Barcode height (including the number) = according to the standard, 25.93mm at standard X
    -- It means there's 9.3333X below the bars but we already took 5X for the longer bars.
    hb.depth = hb.depth + 4.3333 * X

    SILE.call("kern", { width = 7 * X }) -- Right Quiet Zone = minimal 7X

    if addon then
      SILE.call("ean13:addon", { code = addon, scale = scale, correction = corr, showdigits = options.showdigits })
    end
  end, "Typesets an EAN-13 barcode.")

  -- We split the Add-on code in a separate command for easier reading,
  -- but of course it's kind of internal (and hence not mentioned in the
  -- package documentation, though used in an example).
  self:registerCommand("ean13:addon", function (options, _)
    local code = SU.required(options, "code", "valid EAN-13 add-on code")
    local scale = options.scale or "SC2"
    local corr = SU.boolean(options.correction, true)

    if code:match("%D") ~= nil then
      SU.error("Invalid EAN-13 supplemental code '"..code.."'")
    end

    local module = SC[scale]
    if not module then SU.error("Invalid EAN scale (SC0 to SC9): "..scale) end

    local X = SILE.types.length(module.."mm")
    local H = 66.363636364 -- As per the standard, a minimal 21.90mm at standard X
    local offsetcorr = corr and SILE.types.length("0.020mm") or SILE.types.length()

    local pattern
    if #code == 5 then
      pattern = ean13addOn5(code)
    elseif #code == 2 then
      pattern = ean13addOn2(code)
    else
      SU.error("Invalid EAN-13 add-on length in '"..code.."' (expecting a 2-digit or 5-digit code)")
    end

    SILE.call("kern", { width = 5 * X }) -- Add-on Left Quiet Zone = optional 5X
    -- N.B. Optional in the standard, so the spacing between the main part and the
    -- addon is specified as 7-12X (i.e. including the main code 7X Right Quiet Zone).
    -- To be safer, we go for the 12X variant. It also looks better, IMHO.

    local hb = hbox(function ()
      for i = 1, #pattern do
        local sz = tonumber(pattern:sub(i,i)) * X
        if i % 2 == 0 then
          -- space
          SILE.call("kern", { width = sz + offsetcorr })
        else
          -- bar
          SILE.call("hrule", { height = (H - 5) * X, depth = 5 * X, width = sz - offsetcorr })
        end
      end
      SILE.call("kern", { width = offsetcorr }) -- Not really requested by the standard but felt preferable,
                                                -- so that whatever the correction is, the look is globally
                                                -- the same.
      if SU.boolean(options.showdigits, true) then
        -- N.B. Option showdigits undocumented (just used for testing)
        SILE.call("font", { family = SILE.scratch.ean13.font.family,
                            filename = SILE.scratch.ean13.font.filename,
                            size = SILE.scratch.ean13.computed.size * X }, function ()
          SILE.call("raise", { height = (H - 4) * X }, function () -- 0.5X minimum between character and bars,
                                                                   -- but it looks much better with a full 1X.
            SILE.call("kern", { width = -9 * #code * X })
            for i = 1, #code do
              local h = hbox({ code:sub(i,i) }) -- Distribute the digits
              h.width = SILE.types.length()
              SILE.call("kern", { width = 9 * X })
            end
            local l = SILE.types.length((5 - SILE.scratch.ean13.computed.width) * X)
            SILE.call("kern", { width = l })
            local h = hbox({ ">" }) -- closing bracket, aligned to the end of the Add-on Right Quiet Zone
            h.width = SILE.types.length()
            SILE.call("kern", { width = (SILE.scratch.ean13.computed.width - 5) * X  })
          end)
        end)
      end
    end)
    -- Barcode height fix (including the number).
    -- We just ensure here the whole box is high enough to take into account the
    -- add-on's human representation, since that one goes on top.
    hb.height = hb.height + 8.3333 * X

    SILE.call("kern", { width = 5 * X }) -- Add-on Right Quiet Zone = minimal 5X
  end, "Typesets an EAN-13 5-digit add-on barcode.")

  self:registerCommand("ean13:font", function (options, _)
    local family = options.family
    local filename = options.filename
    if not family and not filename then
      SU.error("Required family or filename option to set a monospace font for EAN barcodes")
    end
    -- If both are passed, we do not care:
    -- The font command will do its things as usual.
    setupHumanReadableFont({ family = family, filename = filename })
  end, "Sets the font for the human readable interpretation in EAN-13 barcode")
end

package.documentation = [[
\begin{document}
\use[module=packages.barcodes.ean13]
The \autodoc:package{barcodes.ean13} package allows to print out an EAN-13 barcode, suitable
for an ISBN (or ISSN, etc.)

The \autodoc:command{\ean13} command takes a mandatory \autodoc:parameter{code} parameter,
the human representation of the EAN-13 code (including its final control digit).
It checks its consistency and displays the corresponding barcode. By default, it uses the
recommended scale for a “consumer item” (SC2, with a “module” of 0.33mm). The size
can be changed by setting the \autodoc:parameter{scale} option to any of the standard
scales from SC0 to SC9. For the record, SC6 is the minimum recommended scale for an
“outer packaging” (SC9 being the default recommended scale for it).

By default, the bar width is reduced by 0.020mm and the white spaces are enlarged by the
same amount (so as to preserve the global distance between bars.)
The standard indeed recommends making each rule thinner than what is exactly implied
by the multiple of the module, due the ink behavior during the actual printing. The
bar correction value used here is suitable for offset process technology. You can
disable that offset correction by specifying the \autodoc:parameter{correction=false}
option.

The human readable interpretation below the barcode expects the font to be OCR-B.
A free public domain implementation of this font is Matthew Skala’s July 2021 version, at \url{https://tsukurimashou.osdn.jp/ocr.php.en}, recommended for use with this package.
The font is included in the package, for convenience, and is loaded automatically.
The \autodoc:command{\ean13:font[family=<family>]} (or \autodoc:command{\ean13:font[filename=<filename>]}) command allows setting the font family (or file name), would another choice be preferred.
Obviously, a monospace font is strongly advised.
The package does its best for decently sizing and positioning the text, but your mileage may vary depending on the chosen font.

Here is this package in action \ean13[code=9782953989663, scale=SC0] at scale SC0…

…so you can see how it shows up with respect to the current baseline.

Additionally, EAN-13 barcodes may have a 2-digit or 5-digit supplemental “add-on” part,
which can be specified with the \autodoc:parameter{addon} option. The supplemental part
is sometimes used to provide price information or other publisher-specific details,
depending on the type of EAN-13 number and the country where it is registered.

For instance \ean13[code=9782953989663, scale=SC0, addon=12345]
or a 2-digit add-on \ean13:addon[code=24, scale=SC0]
\end{document}]]

return package
