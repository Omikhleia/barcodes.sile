package = "barcodes.sile"
version = "dev-1"
source = {
    url = "git://github.com/Omikhleia/barcodes.sile.git",
    tag = "master"
}
description = {
   summary = "Blah.",
   detailed = [[
     Blah
   ]],
   homepage = "https://github.com/Omikhleia/vbarcodes.sile",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "none",
   install = {
     lua = {
       ["sile.packages.barcodes"]                    = "packages/barcodes/init.lua",
       ["sile.packages.barcodes.ean13"]              = "packages/barcodes/ean13/init.lua",
     },
   }
}
