set rom_version=1.0
set rom_name=FredUnderscoreUnderscorelaffUnderscoreWhiteHatNinetyFourSBDWolfGanbareGoemonTwoPracticeROM_v%rom_version%.sfc

IF NOT EXIST rom_output mkdir rom_output
del /q rom_output
copy rom_source\source.sfc rom_output\%rom_name%
tools\asar\asar.exe --fix-checksum=off gg2ksmpractice.asm rom_output\%rom_name%