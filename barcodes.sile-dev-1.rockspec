package = "barcodes.sile"
version = "dev-1"
source = {
  url = "git://github.com/Omikhleia/barcodes.sile.git",
}
description = {
  summary = "Barcodes package for the SILE typesetting system.",
  detailed = [[
    This package for the SILE typesetter allows printing out an EAN-13 barcode
    suitable for an ISBN (or ISSN, etc.)
  ]],
  homepage = "https://github.com/Omikhleia/barcodes.sile",
  license = "MIT",
}
dependencies = {
  "lua >= 5.1",
}
build = {
  type = "builtin",
  modules = {
    ["sile.packages.barcodes"]         = "packages/barcodes/init.lua",
    ["sile.packages.barcodes.ean13"]   = "packages/barcodes/ean13/init.lua",
  }
}
