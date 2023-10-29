set rom_version=1.0_timerbeta
set rom_name=FredUnderscoreUnderscorelaffUnderscoreWhiteHatNinetyFourSBDWolfGanbareGoemonTwoPracticeROM_v%rom_version%.sfc

IF NOT EXIST rom_output mkdir rom_output
del /q rom_output
copy rom_source\source.sfc rom_output\%rom_name%
tools\asar\asar.exe --no-title-check gg2ksmpractice.asm rom_output\%rom_name%