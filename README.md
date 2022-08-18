# ptable.sile

[![license](https://img.shields.io/github/license/Omikhleia/ptable.sile)](LICENSE)

This package set for the [SILE](https://github.com/sile-typesetter/sile) typesetting
system aims at providing barcode support.

It currently provides the `barcodes.ean13` package, which allows printing out an EAN-13
barcode, suitable for an ISBN (or ISSN, etc.)

![EAN-13 barcodes](ean13.png "ISBN examples")

## Installation

These packages require SILE v0.14 or upper.

Installation relies on the **luarocks** package manager.

To install the latest development version, you may use the provided “rockspec”:

```
luarocks --lua-version 5.4  install https://raw.githubusercontent.com/Omikhleia/barcodes.sile/main/barcodes.sile-dev-1.rockspec
```

(Adapt to you version of Lua, if need be, and refer to the SILE manual for more
detailed installation information.)
